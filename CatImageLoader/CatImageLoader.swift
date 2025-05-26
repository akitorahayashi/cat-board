import CBModel
import CatAPIClient
import CatImageURLRepository
import CatImageScreener
import Kingfisher
import SwiftUI
import SwiftData

public actor CatImageLoader: CatImageLoaderProtocol {
    private let repository: CatImageURLRepositoryProtocol
    private let imageClient: CatAPIClient
    private let screener: CatImageScreener
    private var isPrefetching: Bool = false
    private var prefetchTask: Task<Void, Never>?
    private var prefetchedImages: [CatImageURLModel] = []
    private let modelContainer: ModelContainer

    // プリフェッチ関連の定数
    private static let prefetchBatchCount = 10 // 一回のプリフェッチでロードして screener に通す枚数
    private static let targetPrefetchCount = 150 // プリフェッチの目標枚数
    private static let maxFetchAttempts = 30 // 最大取得試行回数

    public init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        self.repository = CatImageURLRepository(modelContainer: modelContainer)
        self.imageClient = CatAPIClient()
        self.screener = CatImageScreener()
    }

    deinit {
        prefetchTask?.cancel()
        KingfisherManager.shared.cache.clearMemoryCache()
    }

    public func getPrefetchedCount() async -> Int {
        prefetchedImages.count
    }

    public func getPrefetchedImages(count: Int) async -> [CatImageURLModel] {
        let batchCount = min(count, prefetchedImages.count)
        let batch = Array(prefetchedImages.prefix(batchCount))
        prefetchedImages.removeFirst(batchCount)
        return batch
    }

    public func fetchImages(count: Int) async throws -> [CatImageURLModel] {
        let newImages = try await repository.getNextImageURLs(count: count)

        var loadedImages: [CGImage] = []
        var loadedModels: [CatImageURLModel] = []

        // 画像のダウンロードとスクリーニングを行う
        for item in newImages {
            guard let url = URL(string: item.imageURL) else { continue }
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
                if let cgImage = result.image.cgImage {
                    loadedImages.append(cgImage)
                    loadedModels.append(item)
                }
            } catch {
                print("画像のダウンロードに失敗（URL: \(item.imageURL)）: \(error.localizedDescription)")
                continue
            }
        }

        // スクリーニングを実行
        if !loadedImages.isEmpty {
            let filteredModels = try await screener.screenImages(
                cgImages: loadedImages,
                models: loadedModels
            )

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

            print("画像取得完了: \(loadedImages.count)枚読み込み → スクリーニング通過\(filteredModels.count)枚")
            return filteredModels
        }

        return []
    }

    public func startPrefetchingIfNeeded() async {
        guard !isPrefetching else { return }
        guard prefetchedImages.count < Self.targetPrefetchCount else { return }

        prefetchTask?.cancel()
        isPrefetching = true

        prefetchTask = Task { [weak self] in
            guard let self else { return }
            await self.prefetchImages()
            await self.setPrefetching(false)
        }
    }

    private func setPrefetching(_ value: Bool) {
        isPrefetching = value
    }

    private func prefetchImages() async {
        do {
            // 必要なプリフェッチ枚数を計算
            let remainingCount = Self.targetPrefetchCount - prefetchedImages.count
            print(
                "プリフェッチ開始: 現在\(prefetchedImages.count)枚 → 目標\(Self.targetPrefetchCount)枚 (残り\(remainingCount)枚)"
            )

            var totalFetched = 0
            var totalScreened = 0

            while prefetchedImages.count < Self.targetPrefetchCount && totalFetched < Self.maxFetchAttempts * Self.prefetchBatchCount {
                let filteredModels = try await fetchImages(count: Self.prefetchBatchCount)
                totalFetched += Self.prefetchBatchCount
                totalScreened += filteredModels.count

                prefetchedImages += filteredModels
                print("画像プリフェッチバッチ完了: \(Self.prefetchBatchCount)枚取得 → スクリーニング通過\(filteredModels.count)枚追加 (現在\(prefetchedImages.count)枚)")

                if prefetchedImages.count >= Self.targetPrefetchCount {
                    print("プリフェッチ完了: 目標\(Self.targetPrefetchCount)枚に達しました")
                    break
                }
            }

            if prefetchedImages.count < Self.targetPrefetchCount {
                print("プリフェッチ終了: 最大試行回数に達しました (取得\(totalFetched)枚, 通過\(totalScreened)枚, 現在\(prefetchedImages.count)枚)")
            }
        } catch let error as NSError {
            print("プリフェッチ中にエラーが発生: \(error.localizedDescription)")
        }
    }
} 
