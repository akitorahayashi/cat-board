import Foundation
import SwiftData
import CBShared

public actor CatImageURLRepository {
    private let modelContext: ModelContext
    private var loadedImageURLs: [CatImageURLModel] = []

    private let maxLoadedURLCount = 100
    private let minLoadedURLThreshold = 30
    private let maxStoredURLCount = 200
    private let apiFetchBatchSize = 10

    /// 初期化 データベースへのアクセスに使う modelContext を持つ
    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    /// 指定した数の画像URLを返す
    /// なければAPIから取って返す
    /// 終わったら裏で補充
    public func provideImageURLs(imagesCount: Int, using apiClient: CatAPIClient) async throws -> [CatImageURLModel] {
        if loadedImageURLs.count < imagesCount {
            print("キャッシュ不足: 現在\(loadedImageURLs.count)枚 → API経由で\(imagesCount)枚取得")
            let fetched = try await apiClient.fetchImageURLs(
                totalCount: imagesCount,
                batchSize: apiFetchBatchSize
            )

            Task {
                try? await self.refillIfNeeded(using: apiClient)
            }

            return Array(fetched.prefix(imagesCount))
        }

        let count = min(imagesCount, loadedImageURLs.count)
        let provided = Array(loadedImageURLs.prefix(count))
        loadedImageURLs.removeFirst(count)
        print("キャッシュから提供完了: \(count)枚提供 → 残り\(loadedImageURLs.count)枚")

        if loadedImageURLs.count <= minLoadedURLThreshold {
            Task {
                try? await self.refillIfNeeded(using: apiClient)
            }
        }

        return provided
    }

    /// 保存済みの画像URLを読み込んで loadedImageURLs に足す
    func loadImageURLs(limit: Int? = nil) throws -> [CatImageURLModel] {
        var descriptor = FetchDescriptor<CatImageURLEntity>(
            sortBy: [.init(\.createdAt, order: .forward)]
        )
        if let limit = limit {
            descriptor.fetchLimit = limit
        }
        let entities = try modelContext.fetch(descriptor)
        let beforeCount = self.loadedImageURLs.count
        self.loadedImageURLs += entities.map(CatImageURLModel.init(entity:))
        print("データベースから読み込み完了: \(entities.count)枚追加 → 現在\(self.loadedImageURLs.count)枚")
        return entities.map(CatImageURLModel.init(entity:))
    }

    /// URLが少なくなったら補充する 永続化があれば使い なければAPIから取得して保存
    func refillIfNeeded(using apiClient: CatAPIClient) async throws {
        if loadedImageURLs.count > minLoadedURLThreshold { return }

        let neededToLoad = maxLoadedURLCount - loadedImageURLs.count
        print("キャッシュ補充開始: 現在\(loadedImageURLs.count)枚 → 目標\(maxLoadedURLCount)枚(\(neededToLoad)枚追加予定)")
        let fetched = try await apiClient.fetchImageURLs(totalCount: neededToLoad, batchSize: apiFetchBatchSize)
        self.loadedImageURLs += fetched

        var currentStored = try modelContext.fetchCount(FetchDescriptor<CatImageURLEntity>())
        let initialStored = currentStored
        while currentStored < maxStoredURLCount {
            let remaining = maxStoredURLCount - currentStored
            let times = Int(ceil(Double(remaining) / Double(apiFetchBatchSize)))
            let newlyStored = try await fetchAndStoreImageURLs(apiClient: apiClient, imageCountPerFetch: apiFetchBatchSize, timesOfFetch: times)
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
        let fetched = try await apiClient.fetchImageURLs(totalCount: imageCountPerFetch * timesOfFetch, batchSize: imageCountPerFetch)
        
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
