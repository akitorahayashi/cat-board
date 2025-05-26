import CBModel
import CatAPIClient
import Foundation
import SwiftData

public actor CatImageURLRepository: CatImageURLRepositoryProtocol {
    
    private var loadedImageURLs: [CatImageURLModel] = []
    private var isRefilling: Bool = false
    private var refillTask: Task<Void, Never>?
    private let modelContainer: ModelContainer

    private let maxLoadedURLCount = 300
    private let loadedURLThreshold = 100
    private let maxStoredURLCount = 300
    private let storedURLThreshold = 100
    private let apiFetchBatchSize = 10

    public init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        // 初期化時にデータベースからURLを読み込む
        Task {
            await loadInitialImageURLsFromSwiftData()
        }
    }

    deinit {
        refillTask?.cancel()
    }

    /// 初期化時にデータベースから画像URLを読み込む
    private func loadInitialImageURLsFromSwiftData() async {
        print("SwiftDataから初期URL読み込み開始: 目標\(maxLoadedURLCount)枚")
        do {
            let loaded = try await dbLoadImageURLs(limit: maxLoadedURLCount)
            loadedImageURLs = loaded
            print("SwiftDataから初期URL読み込み完了: \(loaded.count)枚")
        } catch {
            print("SwiftDataから初期URL読み込み失敗: \(error.localizedDescription)")
            // エラーが発生しても空の配列で開始
            loadedImageURLs = []
        }
    }

    /// データベースから画像URLを読み込んで loadedImageURLs に足す
    @MainActor
    private func dbLoadImageURLs(limit: Int? = nil) async throws -> [CatImageURLModel] {
        let modelContext = modelContainer.mainContext
        var descriptor = FetchDescriptor<CatImageURLEntity>(
            sortBy: [.init(\.createdAt, order: .forward)]
        )

        // 必要な分だけを取得
        let neededCount = limit ?? maxLoadedURLCount
        descriptor.fetchLimit = neededCount

        let entities = try modelContext.fetch(descriptor)
        let models = entities.map(CatImageURLModel.init(entity:))

        // 取得したエンティティを削除
        for entity in entities {
            modelContext.delete(entity)
        }
        try modelContext.save()

        print("SwiftDataからloadedImageURLsへ移行: \(entities.count)件のURLを取得し、\(models.count)件を移行完了")
        return models
    }

    /// 指定した数の画像URLを返す
    /// なければAPIから取って返す
    /// 終わったら裏で補充
    public func getNextImageURLsFromCacheOrAPI(
        count: Int,
        using apiClient: CatAPIClient
    ) async throws -> [CatImageURLModel] {
        // キャッシュが十分にある場合
        if loadedImageURLs.count >= count {
            let provided = try await getImageURLsFromLoadedURLs(count: count, using: apiClient)

            // 提供後の残りが閾値以下になった場合、補充を開始
            if loadedImageURLs.count <= loadedURLThreshold {
                let neededToLoad = maxLoadedURLCount - loadedImageURLs.count
                print("loadedImageURLs補充開始: 現在\(loadedImageURLs.count)枚 → 目標\(maxLoadedURLCount)枚(\(neededToLoad)枚追加予定)")
                await startBackgroundURLRefill(using: apiClient)
            }

            return provided
        }

        // キャッシュが不足している場合
        // 1. 利用可能なキャッシュを全て提供
        let available = try await getImageURLsFromLoadedURLs(count: loadedImageURLs.count, using: apiClient)
        // 2. 残りをAPIから取得
        let remaining = try await apiClient.fetchImageURLs(
            totalCount: count - available.count,
            batchSize: apiFetchBatchSize
        )
        // 3. 補充を開始
        await startBackgroundURLRefill(using: apiClient)

        print(
            "URL供給完了: loadedImageURLsから\(available.count)枚 + APIから\(remaining.count)枚 = 合計\(available.count + remaining.count)枚"
        )
        return available + remaining
    }

    /// キャッシュから画像URLを提供
    private func getImageURLsFromLoadedURLs(count: Int, using _: CatAPIClient) async throws -> [CatImageURLModel] {
        let count = min(count, loadedImageURLs.count)
        let provided = Array(loadedImageURLs.prefix(count))
        loadedImageURLs = Array(loadedImageURLs.dropFirst(count)) // 提供した分を確実に削除
        print("loadedImageURLsから提供: \(count)枚提供 → 残り\(loadedImageURLs.count)枚")
        return provided
    }

    /// バックグラウンドでの補充処理を開始
    private func startBackgroundURLRefill(using apiClient: CatAPIClient) async {
        // 既に補充中なら何もしない
        guard !isRefilling else { return }

        // loadedImageURLsが十分にある場合は補充しない
        guard loadedImageURLs.count <= loadedURLThreshold else {
            print("loadedImageURLs補充不要: 現在\(loadedImageURLs.count)枚(閾値\(loadedURLThreshold)枚)")
            return
        }

        // 前回のタスクをキャンセル
        refillTask?.cancel()

        // 新しいタスクを開始
        refillTask = Task { [weak self] in
            guard let self else { return }
            do {
                await self.setRefilling(true)
                try await refillLoadedURLsIfNeeded(using: apiClient)
            } catch {
                print("loadedImageURLsのバックグラウンド補充に失敗: \(error.localizedDescription)")
            }
            await self.setRefilling(false)
        }
    }

    private func setRefilling(_ value: Bool) {
        isRefilling = value
    }

    /// キャッシュのURLが少なくなったら補充する
    private func refillLoadedURLsIfNeeded(using apiClient: CatAPIClient) async throws {
        if loadedImageURLs.count > loadedURLThreshold { return }

        let neededToLoad = maxLoadedURLCount - loadedImageURLs.count
        print("loadedImageURLs補充開始: 現在\(loadedImageURLs.count)枚 → 目標\(maxLoadedURLCount)枚(\(neededToLoad)枚追加予定)")

        // まずデータベースから読み込める分を読み込む
        let storedURLs = try await dbLoadImageURLs(limit: neededToLoad)
        if !storedURLs.isEmpty {
            loadedImageURLs += storedURLs
            print("loadedImageURLs補充完了: \(storedURLs.count)枚追加 → 現在\(loadedImageURLs.count)枚")
        }

        // まだ必要な分があればAPIから取得
        if loadedImageURLs.count < maxLoadedURLCount {
            let remainingToLoad = maxLoadedURLCount - loadedImageURLs.count
            let fetched = try await apiClient.fetchImageURLs(totalCount: remainingToLoad, batchSize: apiFetchBatchSize)
            loadedImageURLs += fetched
            print("APIからloadedImageURLsへ補充: \(fetched.count)枚追加 → 現在\(loadedImageURLs.count)枚")
        }

        // データベースの補充
        var currentStored = try await fetchStoredURLCount()
        if currentStored <= storedURLThreshold {
            print("SwiftData URL補充開始: 現在\(currentStored)件 → 目標\(maxStoredURLCount)件")
            while currentStored < maxStoredURLCount {
                let remaining = maxStoredURLCount - currentStored
                let times = Int(ceil(Double(remaining) / Double(apiFetchBatchSize)))
                let newlyStored = try await fetchAndStoreImageURLsToSwiftData(
                    apiClient: apiClient,
                    imageCountPerFetch: apiFetchBatchSize,
                    timesOfFetch: times
                )
                if newlyStored == 0 { break }
                currentStored += newlyStored
            }
            print("SwiftData URL補充完了: \(currentStored)件")
        } else {
            print("SwiftData URL補充不要: 現在\(currentStored)件(閾値\(storedURLThreshold)件)")
        }
        print("キャッシュ更新完了: loadedImageURLs=\(loadedImageURLs.count)枚, SwiftData=\(currentStored)件")

        // プリフェッチ後も閾値を下回っている場合は再度補充を開始
        if loadedImageURLs.count <= loadedURLThreshold {
            print("loadedImageURLsが閾値を下回っているため、追加の補充を開始: 現在\(loadedImageURLs.count)枚")
            try await refillLoadedURLsIfNeeded(using: apiClient)
        }
    }

    /// APIから画像URLを取って 保存する
    @MainActor
    func fetchAndStoreImageURLsToSwiftData(
        apiClient: CatAPIClient,
        imageCountPerFetch: Int = 10,
        timesOfFetch: Int = 3
    ) async throws -> Int {
        let modelContext = modelContainer.mainContext
        var totalStored = 0
        for _ in 0..<timesOfFetch {
            let urls = try await apiClient.fetchImageURLs(totalCount: imageCountPerFetch, batchSize: imageCountPerFetch)
            for url in urls {
                let entity = CatImageURLEntity(model: url)
                modelContext.insert(entity)
            }
            try modelContext.save()
            totalStored += urls.count
        }
        return totalStored
    }

    public func getNextImageURLs(count: Int) async throws -> [CatImageURLModel] {
        return try await getNextImageURLsFromCacheOrAPI(
            count: count,
            using: CatAPIClient()
        )
    }

    public func clearCache() async {
        loadedImageURLs = []
        refillTask?.cancel()
        refillTask = nil
        isRefilling = false
    }
    
    @MainActor
    private func fetchStoredURLCount() throws -> Int {
        let modelContext = modelContainer.mainContext
        return try modelContext.fetchCount(FetchDescriptor<CatImageURLEntity>())
    }
}
