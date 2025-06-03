import CatImageLoader
import CatImageScreener
import CatImageURLRepository
import CatURLImageModel
import Kingfisher
import SwiftData
import SwiftUI

public actor CatImagePrefetcher {
    private let repository: CatImageURLRepositoryProtocol
    private let imageLoader: CatImageLoaderProtocol
    private let screener: CatImageScreenerProtocol
    private let modelContainer: ModelContainer
    private var isPrefetching: Bool = false
    private var prefetchTask: Task<Void, Never>?

    // プリフェッチ関連の定数
    private static let prefetchBatchCount = 10 // 一回のプリフェッチでロードして screener に通す枚数
    private static let targetPrefetchCount = 150 // プリフェッチの目標枚数
    private static let maxFetchAttempts = 30 // 最大取得試行回数

    public init(
        repository: CatImageURLRepositoryProtocol,
        imageLoader: CatImageLoaderProtocol,
        screener: CatImageScreenerProtocol,
        modelContainer: ModelContainer
    ) {
        self.repository = repository
        self.imageLoader = imageLoader
        self.screener = screener
        self.modelContainer = modelContainer
    }

    deinit {
        prefetchTask?.cancel()
        KingfisherManager.shared.cache.clearMemoryCache()
    }

    // MARK: - Public Methods

    /// 現在プリフェッチされている画像の数を取得する
    public func getPrefetchedCount() async throws -> Int {
        try await MainActor.run {
            let modelContext = modelContainer.mainContext
            let count = try modelContext.fetchCount(FetchDescriptor<PrefetchedCatImageURL>())
            return count
        }
    }

    /// プリフェッチされた画像を指定された枚数分取得し、データベースから削除する
    public func getPrefetchedImages(imageCount: Int) async throws -> [CatImageURLModel] {
        try await loadAndRemovePrefetchedImages(limit: imageCount)
    }

    /// 現在のプリフェッチ数が目標値未満の場合にプリフェッチを開始する
    public func startPrefetchingIfNeeded() async throws {
        let currentCount = try await getPrefetchedCount()
        guard !isPrefetching else { return }
        guard currentCount < Self.targetPrefetchCount else { return }

        // 前回のタスクをキャンセル
        prefetchTask?.cancel()

        isPrefetching = true
        prefetchTask = Task { [self] in
            do {
                try await prefetchImages()
            } catch {
                print("プリフェッチ中にエラーが発生: \(error.localizedDescription)")
            }
            isPrefetching = false
        }
    }

    // MARK: - Private Methods

    private func prefetchImages() async throws {
        let currentCount = try await getPrefetchedCount()
        let remainingCount = Self.targetPrefetchCount - currentCount
        print("プリフェッチ開始: 現在\(currentCount)枚 → 目標\(Self.targetPrefetchCount)枚 (残り\(remainingCount)枚)")

        var attempts = 0
        var totalFetched = 0

        while try await getPrefetchedCount() < Self.targetPrefetchCount,
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

            // 4. スクリーニングを通過した画像をSwiftDataに保存
            try await storePrefetchedImages(screenedModels)

            // 5. ログ情報を集計
            attempts += 1
            totalFetched += models.count

            // 6. ログ出力
            print(
                "プリフェッチ進捗: \(loadedImages.count)枚中\(screenedModels.count)枚通過 "
                + "(現在\(try await getPrefetchedCount())枚)"
            )
        }
    }

    /// プリフェッチされた画像を指定された枚数分取得し、データベースから削除する
    private func loadAndRemovePrefetchedImages(limit: Int) async throws -> [CatImageURLModel] {
        try await MainActor.run {
            let modelContext = modelContainer.mainContext
            var descriptor = FetchDescriptor<PrefetchedCatImageURL>(
                sortBy: [.init(\.createdAt, order: .forward)]
            )
            descriptor.fetchLimit = limit

            let entities = try modelContext.fetch(descriptor)
            let models = entities.map { CatImageURLModel(prefetched: $0) }

            for entity in entities {
                modelContext.delete(entity)
            }
            try modelContext.save()

            return models
        }
    }

    /// プリフェッチされた画像をSwiftDataに保存する
    private func storePrefetchedImages(_ models: [CatImageURLModel]) async throws {
        try await MainActor.run {
            let modelContext = modelContainer.mainContext
            for model in models {
                let entity = PrefetchedCatImageURL(model: model)
                modelContext.insert(entity)
            }
            try modelContext.save()
        }
    }
}
