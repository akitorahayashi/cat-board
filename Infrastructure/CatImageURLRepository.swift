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
            // 1. Fetch directly from API
            let fetched = try await apiClient.fetchImageURLs(
                totalCount: imagesCount,
                batchSize: apiFetchBatchSize
            )

            // Start background refill
            Task {
                try? await self.refillIfNeeded(using: apiClient)
            }

            return Array(fetched.prefix(imagesCount))
        }

        let count = min(imagesCount, loadedImageURLs.count)
        let provided = Array(loadedImageURLs.prefix(count))
        loadedImageURLs.removeFirst(count)

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
        self.loadedImageURLs += entities.map(CatImageURLModel.init(entity:))
        return entities.map(CatImageURLModel.init(entity:))
    }

    /// URLが少なくなったら補充する 永続化があれば使い なければAPIから取得して保存
    func refillIfNeeded(using apiClient: CatAPIClient) async throws {
        if loadedImageURLs.count > minLoadedURLThreshold { return }

        let neededToLoad = maxLoadedURLCount - loadedImageURLs.count
        let fetched = try await apiClient.fetchImageURLs(totalCount: neededToLoad, batchSize: apiFetchBatchSize)
        self.loadedImageURLs += fetched

        // 永続化層に最大まで補充
        var currentStored = try modelContext.fetchCount(FetchDescriptor<CatImageURLEntity>())
        while currentStored < maxStoredURLCount {
            let remaining = maxStoredURLCount - currentStored
            let times = Int(ceil(Double(remaining) / Double(apiFetchBatchSize)))
            let newlyStored = try await fetchAndStoreImageURLs(apiClient: apiClient, imageCountPerFetch: apiFetchBatchSize, timesOfFetch: times)
            if newlyStored == 0 { break }
            currentStored += newlyStored
        }
    }

    /// APIから画像URLを取って 保存する
    func fetchAndStoreImageURLs(
        apiClient: CatAPIClient,
        imageCountPerFetch: Int = 10,
        timesOfFetch: Int = 3
    ) async throws -> Int {
        var savedCount = 0
        let fetched = try await apiClient.fetchImageURLs(totalCount: imageCountPerFetch * timesOfFetch, batchSize: imageCountPerFetch)
        for model in fetched {
            let entity = CatImageURLEntity(url: model.imageURL)
            modelContext.insert(entity)
            savedCount += 1
        }
        try modelContext.save()
        return savedCount
    }
}
