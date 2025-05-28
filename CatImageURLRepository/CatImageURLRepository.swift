import CatAPIClient
import CBModel
import Foundation
import SwiftData

public actor CatImageURLRepository: CatImageURLRepositoryProtocol {
    private var loadedImageURLs: [CatImageURLModel] = []
    private var refillTask: Task<Void, Never>?
    private let modelContainer: ModelContainer
    private let apiClient: CatAPIClientProtocol

    private let maxLoadedURLCount = 300
    private let loadedURLThreshold = 100
    private let maxStoredURLCount = 300
    private let storedURLThreshold = 100
    private let apiFetchBatchSize = 10

    public init(modelContainer: ModelContainer, apiClient: CatAPIClientProtocol) {
        self.modelContainer = modelContainer
        self.apiClient = apiClient
        Task {
            await loadInitialImageURLsFromSwiftData()
        }
    }

    deinit {
        refillTask?.cancel()
    }

    // MARK: - Public Interface
    public func getNextImageURLs(count: Int) async throws -> [CatImageURLModel] {
        // キャッシュが十分にある場合
        if loadedImageURLs.count >= count {
            let provided = try await getImageURLsFromLoadedURLs(count: count)

            // 提供後の残りが閾値以下になった場合、補充を開始
            if loadedImageURLs.count <= loadedURLThreshold {
                let neededToLoad = maxLoadedURLCount - loadedImageURLs.count
                print(
                    "loadedImageURLs補充開始: 現在\(loadedImageURLs.count)枚 → 目標\(maxLoadedURLCount)枚(\(neededToLoad)枚追加予定)"
                )
                await startBackgroundURLRefill()
            }

            return provided
        }

        // キャッシュが不足している場合
        // 1. 利用可能なキャッシュを全て提供
        let available = try await getImageURLsFromLoadedURLs(count: loadedImageURLs.count)
        // 2. 残りをAPIから取得
        let remaining = try await apiClient.fetchImageURLs(
            totalCount: count - available.count,
            batchSize: apiFetchBatchSize
        )
        // 3. 補充を開始
        await startBackgroundURLRefill()

        print(
            "URL供給完了: loadedImageURLsから\(available.count)枚 + APIから\(remaining.count)枚 = 合計\(available.count + remaining.count)枚"
        )
        return available + remaining
    }

    // MARK: - Private Methods
    private func getImageURLsFromLoadedURLs(count: Int) async throws -> [CatImageURLModel] {
        let count = min(count, loadedImageURLs.count)
        let provided = Array(loadedImageURLs.prefix(count))
        loadedImageURLs = Array(loadedImageURLs.dropFirst(count))
        print("loadedImageURLsから提供: \(count)枚提供 → 残り\(loadedImageURLs.count)枚")
        return provided
    }

    private func startBackgroundURLRefill() async {
        guard refillTask == nil else { return }
        guard loadedImageURLs.count <= loadedURLThreshold else {
            print("loadedImageURLs補充不要: 現在\(loadedImageURLs.count)枚(閾値\(loadedURLThreshold)枚)")
            return
        }

        refillTask = Task { [self] in
            do {
                try await refillLoadedURLsIfNeeded()
            } catch {
                print("loadedImageURLsのバックグラウンド補充に失敗: \(error.localizedDescription)")
            }
            refillTask = nil
        }
    }

    private func refillLoadedURLsIfNeeded() async throws {
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

        if loadedImageURLs.count <= loadedURLThreshold {
            print("loadedImageURLsが閾値を下回っているため、追加の補充を開始: 現在\(loadedImageURLs.count)枚")
            try await refillLoadedURLsIfNeeded()
        }
    }

    // MARK: - Database Operations
    private func loadInitialImageURLsFromSwiftData() async {
        print("SwiftDataから初期URL読み込み開始: 目標\(maxLoadedURLCount)枚")
        do {
            let loaded = try await dbLoadImageURLs(limit: maxLoadedURLCount)
            loadedImageURLs = loaded
            print("SwiftDataから初期URL読み込み完了: \(loaded.count)枚")
        } catch {
            print("SwiftDataから初期URL読み込み失敗: \(error.localizedDescription)")
            loadedImageURLs = []
        }
    }

    private func dbLoadImageURLs(limit: Int? = nil) async throws -> [CatImageURLModel] {
        return try await MainActor.run {
            let modelContext = modelContainer.mainContext
            var descriptor = FetchDescriptor<CatImageURLEntity>(
                sortBy: [.init(\.createdAt, order: .forward)]
            )

            let neededCount = limit ?? maxLoadedURLCount
            descriptor.fetchLimit = neededCount

            let entities = try modelContext.fetch(descriptor)
            let models = entities.map(CatImageURLModel.init(entity:))

            for entity in entities {
                modelContext.delete(entity)
            }
            try modelContext.save()

            print("SwiftDataからloadedImageURLsへ移行: \(entities.count)件のURLを取得し、\(models.count)件を移行完了")
            return models
        }
    }

    private func fetchAndStoreImageURLsToSwiftData(
        imageCountPerFetch: Int = 10,
        timesOfFetch: Int = 3
    ) async throws -> Int {
        var totalStored = 0
        for _ in 0 ..< timesOfFetch {
            // APIリクエストはMainActor.runの外で実行
            let urls = try await apiClient.fetchImageURLs(totalCount: imageCountPerFetch, batchSize: imageCountPerFetch)
            
            // データベース操作のみをMainActor.runで実行
            let stored = try await MainActor.run {
                let modelContext = modelContainer.mainContext
                for url in urls {
                    let entity = CatImageURLEntity(model: url)
                    modelContext.insert(entity)
                }
                try modelContext.save()
                return urls.count
            }
            totalStored += stored
        }
        return totalStored
    }

    private func fetchStoredURLCount() async throws -> Int {
        return try await MainActor.run {
            let modelContext = modelContainer.mainContext
            return try modelContext.fetchCount(FetchDescriptor<CatImageURLEntity>())
        }
    }
}
