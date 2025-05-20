import CBShared
import Foundation
import SwiftData

public actor CatImageURLRepository {
    private let modelContext: ModelContext
    private var loadedImageURLs: [CatImageURLModel] = []
    private var isRefilling: Bool = false
    private var refillTask: Task<Void, Never>?

    private let maxLoadedURLCount = 100
    private let minLoadedURLThreshold = 30
    private let maxStoredURLCount = 200
    private let apiFetchBatchSize = 10

    /// 初期化 データベースへのアクセスに使う modelContext を持つ
    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
        // 初期化時にデータベースからURLを読み込む
        Task {
            try? await loadInitialImageURLs()
        }
    }

    deinit {
        refillTask?.cancel()
    }

    /// 初期化時にデータベースから画像URLを読み込む
    private func loadInitialImageURLs() async throws {
        print("初期データ読み込み開始")
        let loaded = try loadImageURLs(limit: maxLoadedURLCount)
        loadedImageURLs = loaded
        print("初期データ読み込み完了: \(loaded.count)枚")
    }

    /// データベースから画像URLを読み込んで loadedImageURLs に足す
    private func loadImageURLs(limit: Int? = nil) throws -> [CatImageURLModel] {
        var descriptor = FetchDescriptor<CatImageURLEntity>(
            sortBy: [.init(\.createdAt, order: .forward)]
        )
        if let limit {
            descriptor.fetchLimit = limit
        }
        let entities = try modelContext.fetch(descriptor)
        let models = entities.map(CatImageURLModel.init(entity:))
        return models
    }

    /// 指定した数の画像URLを返す
    /// なければAPIから取って返す
    /// 終わったら裏で補充
    public func provideImageURLs(imagesCount: Int, using apiClient: CatAPIClient) async throws -> [CatImageURLModel] {
        // キャッシュが十分にある場合
        if loadedImageURLs.count >= imagesCount {
            let provided = try await provideFromCache(imagesCount: imagesCount, using: apiClient)
            
            // 提供後の残りが閾値以下になった場合、最大数まで補充
            if loadedImageURLs.count <= minLoadedURLThreshold {
                let neededToLoad = maxLoadedURLCount - loadedImageURLs.count
                print("キャッシュ補充開始: 現在\(loadedImageURLs.count)枚 → 目標\(maxLoadedURLCount)枚(\(neededToLoad)枚追加予定)")
                startBackgroundRefill(using: apiClient)
            }
            
            return provided
        }
        
        // キャッシュが閾値以下またはほとんどない場合
        // 1. 利用可能なキャッシュを全て提供
        let available = try await provideFromCache(imagesCount: loadedImageURLs.count, using: apiClient)
        // 2. 残りをAPIから取得
        let remaining = try await fetchAndProvideDirectly(imagesCount: imagesCount - available.count, using: apiClient)
        // 3. 最大数まで補充を開始
        startBackgroundRefill(using: apiClient)
        
        return available + remaining
    }

    /// キャッシュから画像URLを提供
    private func provideFromCache(imagesCount: Int, using apiClient: CatAPIClient) async throws -> [CatImageURLModel] {
        let count = min(imagesCount, loadedImageURLs.count)
        let provided = Array(loadedImageURLs.prefix(count))
        loadedImageURLs.removeFirst(count)
        return provided
    }

    /// APIから直接取得して提供
    private func fetchAndProvideDirectly(imagesCount: Int, using apiClient: CatAPIClient) async throws -> [CatImageURLModel] {
        print("キャッシュ不足: 現在\(loadedImageURLs.count)枚 → API経由で\(imagesCount)枚取得")
        let fetched = try await apiClient.fetchImageURLs(
            totalCount: imagesCount,
            batchSize: apiFetchBatchSize
        )
        return Array(fetched.prefix(imagesCount))
    }

    /// バックグラウンドでの補充処理を開始
    private func startBackgroundRefill(using apiClient: CatAPIClient) {
        // 既に補充中なら何もしない
        guard !isRefilling else { return }
        
        // 前回のタスクをキャンセル
        refillTask?.cancel()
        
        // 新しいタスクを開始
        refillTask = Task { [weak self] in
            guard let self = self else { return }
            do {
                await self.updateIsRefilling(true)
                try await self.refillIfNeeded(using: apiClient)
            } catch {
                print("バックグラウンド補充に失敗: \(error.localizedDescription)")
            }
            await self.updateIsRefilling(false)
        }
    }

    private func updateIsRefilling(_ value: Bool) {
        isRefilling = value
    }

    /// キャッシュのURLが少なくなったら補充する
    /// 1. データベースから読み込める分を読み込む
    /// 2. まだ必要な分があればAPIから取得
    /// 3. データベースの在庫を最大数まで補充
    private func refillIfNeeded(using apiClient: CatAPIClient) async throws {
        if loadedImageURLs.count > minLoadedURLThreshold { return }

        let neededToLoad = maxLoadedURLCount - loadedImageURLs.count
        print("キャッシュ補充開始: 現在\(loadedImageURLs.count)枚 → 目標\(maxLoadedURLCount)枚(\(neededToLoad)枚追加予定)")

        // まずデータベースから読み込める分を読み込む
        let storedURLs = try loadImageURLs(limit: neededToLoad)
        if !storedURLs.isEmpty {
            loadedImageURLs += storedURLs
        }

        // まだ必要な分があればAPIから取得
        if loadedImageURLs.count < maxLoadedURLCount {
            let remainingToLoad = maxLoadedURLCount - loadedImageURLs.count
            let fetched = try await apiClient.fetchImageURLs(totalCount: remainingToLoad, batchSize: apiFetchBatchSize)
            loadedImageURLs += fetched
        }

        // データベースの補充
        var currentStored = try modelContext.fetchCount(FetchDescriptor<CatImageURLEntity>())
        let initialStored = currentStored
        while currentStored < maxStoredURLCount {
            let remaining = maxStoredURLCount - currentStored
            let times = Int(ceil(Double(remaining) / Double(apiFetchBatchSize)))
            let newlyStored = try await fetchAndStoreImageURLs(
                apiClient: apiClient,
                imageCountPerFetch: apiFetchBatchSize,
                timesOfFetch: times
            )
            if newlyStored == 0 { break }
            currentStored += newlyStored
        }
        print("データベース補充完了: \(initialStored)件から\(currentStored - initialStored)件追加 → 合計\(currentStored)件")
    }

    /// APIから画像URLを取って 保存する
    func fetchAndStoreImageURLs(
        apiClient: CatAPIClient,
        imageCountPerFetch: Int = 10,
        timesOfFetch: Int = 3
    ) async throws -> Int {
        print("画像URL保存処理開始: \(imageCountPerFetch)枚×\(timesOfFetch)回取得予定")
        var savedCount = 0
        let fetched = try await apiClient.fetchImageURLs(
            totalCount: imageCountPerFetch * timesOfFetch,
            batchSize: imageCountPerFetch
        )

        // 既存のURLを取得
        let existingURLs = try modelContext.fetch(FetchDescriptor<CatImageURLEntity>()).map(\.url)

        for model in fetched {
            // 既存のURLと重複していない場合のみ保存
            if !existingURLs.contains(model.imageURL) {
                let entity = CatImageURLEntity(url: model.imageURL)
                modelContext.insert(entity)
                savedCount += 1
            }
        }

        if savedCount > 0 {
            try modelContext.save()
        }
        print("画像URL保存完了: \(fetched.count)枚取得 → \(savedCount)枚保存(重複除外)")
        return savedCount
    }
}
