import CatImageLoader
import CatImageScreener
import CatImageURLRepository
import CBModel
import Kingfisher
import SwiftUI

public actor CatImagePrefetcher {
    private let repository: CatImageURLRepositoryProtocol
    private let imageLoader: CatImageLoaderProtocol
    private let screener: CatImageScreenerProtocol
    private var isPrefetching: Bool = false
    private var prefetchTask: Task<Void, Never>?
    private var prefetchedImages: [CatImageURLModel] = []

    // プリフェッチ関連の定数
    private static let prefetchBatchCount = 10 // 一回のプリフェッチでロードして screener に通す枚数
    private static let targetPrefetchCount = 150 // プリフェッチの目標枚数
    private static let maxFetchAttempts = 30 // 最大取得試行回数

    public init(
        repository: CatImageURLRepositoryProtocol,
        imageLoader: CatImageLoaderProtocol,
        screener: CatImageScreenerProtocol
    ) {
        self.repository = repository
        self.imageLoader = imageLoader
        self.screener = screener
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

    /// 現在のプリフェッチ数が目標値未満の場合にプリフェッチを開始する
    public func startPrefetchingIfNeeded() async {
        let currentCount = await getPrefetchedCount()
        guard !isPrefetching else { return }
        guard currentCount < Self.targetPrefetchCount else { return }

        // 前回のタスクをキャンセル
        prefetchTask?.cancel()

        isPrefetching = true
        prefetchTask = Task { [self] in
            await prefetchImages()
            isPrefetching = false
        }
    }

    // MARK: - Private Methods

    private func prefetchImages() async {
        do {
            let currentCount = await getPrefetchedCount()
            let remainingCount = Self.targetPrefetchCount - currentCount
            print("プリフェッチ開始: 現在\(currentCount)枚 → 目標\(Self.targetPrefetchCount)枚 (残り\(remainingCount)枚)")

            var attempts = 0
            var totalFetched = 0

            while prefetchedImages.count < Self.targetPrefetchCount,
                  attempts < Self.maxFetchAttempts
            {
                if Task.isCancelled {
                    print("プリフェッチがキャンセルされました")
                    break
                }

                // 1. 画像URLの取得
                let models = try await repository.getNextImageURLs(count: Self.prefetchBatchCount)

                // 2. 画像のダウンロード
                let loadedImages = try await imageLoader.loadImageData(from: models)

                // 3. スクリーニングの実行
                let screenedModels = try await screener.screenImages(imageDataWithModels: loadedImages)

                // 4. ログ情報を集計
                attempts += 1
                totalFetched += models.count
                prefetchedImages += screenedModels

                // 5. ログ出力
                print(
                    "プリフェッチ進捗: \(loadedImages.count)枚中\(screenedModels.count)枚通過 (現在\(prefetchedImages.count)枚)"
                )
            }
        } catch {
            print("プリフェッチ中にエラーが発生: \(error.localizedDescription)")
            isPrefetching = false
        }
    }
}
