import CatAPIClient
import CatImageScreener
import CatImageURLRepository
import CBModel
import Kingfisher
import SwiftData
import SwiftUI

public actor CatImageLoader: CatImageLoaderProtocol {
    private let repository: CatImageURLRepositoryProtocol
    private let imageClient: CatAPIClientProtocol
    private let screener: CatImageScreenerProtocol
    private var isPrefetching: Bool = false
    private var prefetchTask: Task<Void, Never>?
    private var prefetchedImages: [CatImageURLModel] = []
    private let modelContainer: ModelContainer

    // プリフェッチ関連の定数
    private static let prefetchBatchCount = 10 // 一回のプリフェッチでロードして screener に通す枚数
    private static let targetPrefetchCount = 150 // プリフェッチの目標枚数
    private static let maxFetchAttempts = 30 // 最大取得試行回数

    public init(
        modelContainer: ModelContainer,
        repository: CatImageURLRepositoryProtocol,
        screener: CatImageScreenerProtocol,
        imageClient: CatAPIClientProtocol
    ) {
        self.modelContainer = modelContainer
        self.repository = repository
        self.imageClient = imageClient
        self.screener = screener

        // Kingfisherのキャッシュ設定
        let diskCache = KingfisherManager.shared.cache.diskStorage

        // ディスクキャッシュの制限: 500MB
        diskCache.config.sizeLimit = 500 * 1024 * 1024
        diskCache.config.expiration = .days(3) // 3日間保持
    }

    deinit {
        prefetchTask?.cancel()
        KingfisherManager.shared.cache.clearMemoryCache()
    }

    // MARK: - Public Methods

    /// 現在プリフェッチされている画像の数を取得する
    public func getPrefetchedCount() async -> Int {
        prefetchedImages.count
    }

    /// プリフェッチされた画像を指定された枚数分取得し、内部の配列から削除する
    public func getPrefetchedImages(imageCount: Int) async -> [CatImageURLModel] {
        let batchCount = min(imageCount, prefetchedImages.count)
        let batch = Array(prefetchedImages.prefix(batchCount))
        prefetchedImages.removeFirst(batchCount)
        return batch
    }

    /// 指定された枚数の画像を取得し、スクリーニングを実行して通過した画像のみを返す
    public func loadImagesWithScreening(count: Int) async throws -> [CatImageURLModel] {
        let urls = try await repository.getNextImageURLs(count: count)
        let loadedImages = try await loadImageData(from: urls)

        if loadedImages.isEmpty {
            print("取得可能な画像がありませんでした")
            return []
        }

        // スクリーニング実行
        let filteredModels = try await screener.screenImages(imageDataWithModels: loadedImages)

        print("スクリーニング結果: \(loadedImages.count)枚中\(filteredModels.count)枚通過")
        return filteredModels
    }

    /// 現在のプリフェッチ数が目標値未満の場合にプリフェッチを開始する
    public func startPrefetchingIfNeeded() async {
        guard !isPrefetching else { return }
        guard prefetchedImages.count < Self.targetPrefetchCount else { return }

        prefetchTask?.cancel()
        isPrefetching = true

        prefetchTask = Task { [self] in
            await prefetchImages()
            isPrefetching = false
        }
    }

    // MARK: - Private Methods

    private func loadImageData(from models: [CatImageURLModel]) async throws -> [(
        imageData: Data,
        model: CatImageURLModel
    )] {
        var loadedImages: [(imageData: Data, model: CatImageURLModel)] = []
        loadedImages.reserveCapacity(models.count)

        for (index, item) in models.enumerated() {
            guard let url = URL(string: item.imageURL) else {
                print("無効なURL: \(item.imageURL)")
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
                        }),
                    ]
                )

                autoreleasepool {
                    if let imageData = result.image.jpegData(compressionQuality: 0.8) {
                        loadedImages.append((imageData: imageData, model: item))
                    }
                }
            } catch let error as NSError {
                if error.domain == NSURLErrorDomain, error.code == NSURLErrorNotConnectedToInternet {
                    throw error
                }
                let errorType = error.domain == NSURLErrorDomain ? "ネットワーク" : "その他"
                print("画像のダウンロードに失敗 [\(index + 1)/\(models.count)]: \(errorType)エラー (\(item.imageURL))")
                continue
            }
        }
        return loadedImages
    }

    private func prefetchImages() async {
        do {
            let remainingCount = Self.targetPrefetchCount - prefetchedImages.count
            print("プリフェッチ開始: 現在\(prefetchedImages.count)枚 → 目標\(Self.targetPrefetchCount)枚 (残り\(remainingCount)枚)")

            var totalFetched = 0
            var totalScreened = 0

            while prefetchedImages.count < Self.targetPrefetchCount,
                  totalFetched < Self.maxFetchAttempts * Self.prefetchBatchCount
            {
                if Task.isCancelled {
                    print("プリフェッチがキャンセルされました")
                    break
                }

                // 1. 画像のURLを取得・ダウンロード
                let urls = try await repository.getNextImageURLs(count: Self.prefetchBatchCount)
                let loadedImages = try await loadImageData(from: urls)

                // 2. スクリーニングの実行
                let screenedModels = try await screener.screenImages(imageDataWithModels: loadedImages)

                // 3. ログ情報を集計
                totalFetched += Self.prefetchBatchCount
                totalScreened += screenedModels.count
                prefetchedImages += screenedModels

                // 4. ログ出力
                print(
                    "プリフェッチ進捗: \(loadedImages.count)枚中\(screenedModels.count)枚通過 (現在\(prefetchedImages.count)枚)"
                )
            }
        } catch {
            print("プリフェッチ中にエラーが発生: \(error.localizedDescription)")
        }
    }
}
