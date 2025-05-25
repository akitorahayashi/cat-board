import CBShared
import Infrastructure
import Kingfisher
import ScaryCatScreeningKit
import SwiftUI

class GalleryViewModel: ObservableObject {
    @Published var imageURLsToShow: [CatImageURLModel] = []
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false

    private let repository: CatImageURLRepository
    private let imageClient: CatAPIClient

    // 画像取得関連の定数
    private static let imagesPerFetch = 10
    private static let maxImageCount = 300
    private static let targetInitialDisplayCount = 20
    private static let batchDisplayCount = 10

    // スクリーニング関連
    private static let isScreeningEnabled = true
    private static let screeningProbabilityThreshold: Float = 0.85
    private static let scaryMode = false  // 怖い画像のみを表示するモード
    private var screener: ScaryCatScreener?
    private var isPrefetching: Bool = false
    private var prefetchTask: Task<Void, Never>?

    // キャッシュの保存期間関係の定数
    private static let kingfisherCacheSizeLimit: UInt = 500 * 1024 * 1024 // 500MB
    private static let kingfisherCacheExpirationDays = 1

    private var prefetchedImages: [CatImageURLModel] = []
    private static let prefetchBatchCount = 10 // 一回のプリフェッチでロードして screener に通す枚数
    private static let minPrefetchThreshold = 50 // プリフェッチを開始する閾値
    private static let targetPrefetchCount = 100 // プリフェッチの目標枚数

    // MARK: - Initialization

    init(repository: CatImageURLRepository, imageClient: CatAPIClient) {
        self.repository = repository
        self.imageClient = imageClient
        // ディスクキャッシュは使用しないため、設定を削除
    }

    deinit {
        prefetchTask?.cancel()
        KingfisherManager.shared.cache.clearMemoryCache()
    }

    @MainActor func onAppear() {
        if imageURLsToShow.isEmpty {
            print("初期画像の読み込み開始: 現在0枚 → 目標\(Self.targetInitialDisplayCount)枚")
            isLoading = true
            Task {
                do {
                    if screener == nil {
                        screener = try await ScaryCatScreener()
                    }

                    var screenedURLs: [CatImageURLModel] = []
                    var fetchCount = 0
                    let maxFetchAttempts = 3

                    while screenedURLs.count < Self.targetInitialDisplayCount && fetchCount < maxFetchAttempts {
                        let fetchSize = fetchCount == 0 ? Self.targetInitialDisplayCount : Self.batchDisplayCount
                        print("画像URL取得開始: \(fetchCount + 1)回目, \(fetchSize)枚取得予定")
                        
                        let loaded = try await repository.getNextImageURLsFromCacheOrAPI(
                            count: fetchSize,
                            using: imageClient
                        )

                        var remainingURLs = loaded
                        var batchScreenedURLs: [CatImageURLModel] = []

                        // 安全な画像をスクリーニング
                        while !remainingURLs.isEmpty {
                            guard let urlModel = remainingURLs.first,
                                  let url = URL(string: urlModel.imageURL) else {
                                remainingURLs.removeFirst()
                                continue
                            }

                            do {
                                let result = try await KingfisherManager.shared.downloader.downloadImage(
                                    with: url,
                                    options: [
                                        .requestModifier(AnyModifier { request in
                                            var r = request
                                            r.timeoutInterval = 10
                                            return r
                                        })
                                    ]
                                )
                                guard let cgImage = result.image.cgImage else {
                                    remainingURLs.removeFirst()
                                    continue
                                }

                                // 一枚ずつスクリーニング
                                let screeningResults = try await screener?.screen(
                                    cgImages: [cgImage],
                                    probabilityThreshold: Self.screeningProbabilityThreshold,
                                    enableLogging: false
                                )

                                if let results = screeningResults {
                                    let overallResults = SCSOverallScreeningResults(results: results)
                                    if !Self.isScreeningEnabled {
                                        batchScreenedURLs.append(urlModel)
                                    } else if Self.scaryMode {
                                        // 怖いモードの場合、unsafeResultsを使用
                                        if !overallResults.unsafeResults.isEmpty {
                                            batchScreenedURLs.append(urlModel)
                                        }
                                    } else {
                                        // 通常モードの場合、safeResultsを使用
                                        if !overallResults.safeResults.isEmpty {
                                            batchScreenedURLs.append(urlModel)
                                        }
                                    }
                                } else {
                                    batchScreenedURLs.append(urlModel)
                                }
                            } catch {
                                print("画像の読み込みまたはスクリーニングに失敗: \(error.localizedDescription)")
                            }

                            remainingURLs.removeFirst()
                        }

                        screenedURLs += batchScreenedURLs
                        print("\(fetchCount + 1)回目の取得完了: \(batchScreenedURLs.count)枚通過 → 現在\(screenedURLs.count)枚")

                        if screenedURLs.count >= Self.targetInitialDisplayCount {
                            break
                        }

                        fetchCount += 1
                    }

                    print("初期画像の読み込み完了: \(screenedURLs.count)枚表示")

                    // 画像URLの更新を一括で行う
                    await MainActor.run {
                        self.imageURLsToShow = screenedURLs
                        self.isLoading = false
                    }

                    startCatImagePrefetchingIfNeeded()
                } catch let error as NSError {
                    await MainActor.run {
                        self.errorMessage = error.localizedDescription
                        self.imageURLsToShow = []
                        self.isLoading = false
                    }
                }
            }
        }
    }

    @MainActor
    func fetchAdditionalImages() async {
        // 追加取得前にmaxImageCountを超えていたら20枚だけ残す
        if imageURLsToShow.count > Self.maxImageCount {
            imageURLsToShow = Array(imageURLsToShow.suffix(10))
        }
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        do {
            if !prefetchedImages.isEmpty {
                let batchCount = min(Self.batchDisplayCount, prefetchedImages.count)
                let batch = prefetchedImages.prefix(batchCount)
                imageURLsToShow += batch
                prefetchedImages.removeFirst(batchCount)
                print("画像表示完了: プリフェッチから\(batchCount)枚追加 → 現在\(imageURLsToShow.count)枚表示中(残り\(prefetchedImages.count)枚)")

                if prefetchedImages.count <= Self.minPrefetchThreshold {
                    startCatImagePrefetchingIfNeeded()
                }
            } else {
                print("プリフェッチがないため直接取得を開始")
                let newImages = try await repository.getNextImageURLsFromCacheOrAPI(
                    count: Self.batchDisplayCount,
                    using: imageClient
                )

                var loadedImages: [CGImage] = []
                var screenedURLs: [CatImageURLModel] = []

                for urlModel in newImages {
                    guard let url = URL(string: urlModel.imageURL) else { continue }
                    do {
                        let result = try await KingfisherManager.shared.downloader.downloadImage(with: url)
                        if let cgImage = result.image.cgImage {
                            loadedImages.append(cgImage)
                            screenedURLs.append(urlModel)
                        }
                    } catch {
                        continue
                    }
                }

                if screener == nil {
                    screener = try await ScaryCatScreener()
                }

                let screeningResults = try await screener?.screen(
                    cgImages: loadedImages,
                    probabilityThreshold: Self.screeningProbabilityThreshold,
                    enableLogging: false
                )

                // スクリーニング通過した画像のURLのみを保持
                if Self.isScreeningEnabled, let results = screeningResults {
                    let overallResults = SCSOverallScreeningResults(results: results)
                    screenedURLs = overallResults.safeResults.map { result in
                        screenedURLs[loadedImages.firstIndex(of: result.cgImage) ?? 0]
                    }
                }

                imageURLsToShow += screenedURLs
                print(
                    "画像直接取得完了: \(loadedImages.count)枚読み込み → \(Self.isScreeningEnabled ? "スクリーニング通過" : "")\(screenedURLs.count)枚"
                )
            }
        } catch let error as NSError {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    @MainActor
    func startCatImagePrefetchingIfNeeded() {
        guard !isPrefetching else { return }
        guard prefetchedImages.count < Self.targetPrefetchCount else { return }

        prefetchTask?.cancel()

        prefetchTask = Task { [weak self] in
            guard let self else { return }
            let prefetchStartTime = Date()
            do {
                isPrefetching = true

                if screener == nil {
                    screener = try await ScaryCatScreener()
                }

                // 必要なプリフェッチ枚数を計算
                let remainingCount = Self.targetPrefetchCount - prefetchedImages.count
                print(
                    "プリフェッチ開始: 現在\(prefetchedImages.count)枚 → 目標\(Self.targetPrefetchCount)枚 (残り\(remainingCount)枚)"
                )

                var totalFetched = 0
                var totalScreened = 0
                let maxFetchAttempts = 30  // 最大取得試行回数

                while prefetchedImages.count < Self.targetPrefetchCount && totalFetched < maxFetchAttempts * Self.prefetchBatchCount {

                    let newImages = try await repository.getNextImageURLsFromCacheOrAPI(
                        count: Self.prefetchBatchCount,
                        using: imageClient
                    )
                    totalFetched += newImages.count

                    var loadedImages: [CGImage] = []
                    var loadedModels: [CatImageURLModel] = []

                    // 画像のダウンロードとスクリーニングを一括で行う
                    for item in newImages {
                        guard let url = URL(string: item.imageURL) else { continue }
                        do {
                            // プリフェッチ用のダウンロードオプションを設定
                            let options: KingfisherOptionsInfo = [
                                .cacheMemoryOnly,  // メモリキャッシュのみを使用
                                .memoryCacheExpiration(.never),  // スクリーニング中にキャッシュが消えないようにする
                                .memoryCacheAccessExtendingExpiration(.none),  // アクセスによる有効期限の自動延長を無効化
                                .requestModifier(AnyModifier { request in
                                    var r = request
                                    r.timeoutInterval = 10
                                    return r
                                })
                            ]
                            let result = try await KingfisherManager.shared.downloader.downloadImage(
                                with: url,
                                options: options
                            )
                            if let cgImage = result.image.cgImage {
                                loadedImages.append(cgImage)
                                loadedModels.append(item)
                            }
                        } catch {
                            print("画像のダウンロードに失敗（URL: \(item.imageURL)）: \(error.localizedDescription)")
                            continue
                        }
                    }

                    // スクリーニングを一括で実行
                    if !loadedImages.isEmpty {
                        do {
                            let screeningResults = try await screener?.screen(
                                cgImages: loadedImages,
                                probabilityThreshold: Self.screeningProbabilityThreshold,
                                enableLogging: false
                            )

                            // Capture the number of downloaded images before filtering
                            let downloadedCount = loadedImages.count

                            var filteredModels: [CatImageURLModel] = []
                            if Self.isScreeningEnabled, let results = screeningResults {
                                let overallResults = SCSOverallScreeningResults(results: results)
                                if Self.scaryMode {
                                    // 怖いモードの場合、unsafeResultsを使用
                                    filteredModels = overallResults.unsafeResults.map { result in
                                        loadedModels[loadedImages.firstIndex(of: result.cgImage) ?? 0]
                                    }
                                } else {
                                    // 通常モードの場合、safeResultsを使用
                                    filteredModels = overallResults.safeResults.map { result in
                                        loadedModels[loadedImages.firstIndex(of: result.cgImage) ?? 0]
                                    }
                                }

                                // 通過しなかった画像のキャッシュをクリア
                                let failedIndices = Set(0..<loadedImages.count).subtracting(
                                    filteredModels.map { model in
                                        loadedModels.firstIndex(of: model) ?? -1
                                    }
                                )
                                for index in failedIndices {
                                    if let url = URL(string: loadedModels[index].imageURL) {
                                        try? await KingfisherManager.shared.cache.removeImage(forKey: url.absoluteString)
                                    }
                                }

                                // 通過しなかった画像のメモリを解放
                                loadedImages.removeAll()
                                loadedModels.removeAll()
                            } else {
                                filteredModels = loadedModels
                            }

                            totalScreened += filteredModels.count
                            await MainActor.run {
                                self.prefetchedImages += filteredModels
                                print("画像プリフェッチバッチ完了: \(downloadedCount)枚読み込み → \(Self.isScreeningEnabled ? "スクリーニング通過" : "")\(filteredModels.count)枚追加 (現在\(self.prefetchedImages.count)枚)")
                            }
                        } catch {
                            print("スクリーニングに失敗: \(error.localizedDescription)")
                        }
                    }

                    if prefetchedImages.count >= Self.targetPrefetchCount {
                        print("プリフェッチ完了: 目標\(Self.targetPrefetchCount)枚に達しました")
                        break
                    }
                }

                if prefetchedImages.count < Self.targetPrefetchCount {
                    print("プリフェッチ終了: 最大試行回数に達しました (取得\(totalFetched)枚, 通過\(totalScreened)枚, 現在\(prefetchedImages.count)枚)")
                }
            } catch let error as NSError {
                errorMessage = error.localizedDescription
            }
            let elapsed = Date().timeIntervalSince(prefetchStartTime)
            print("プリフェッチ完了までの所要時間: \(elapsed)秒")
            isPrefetching = false
        }
    }
}
