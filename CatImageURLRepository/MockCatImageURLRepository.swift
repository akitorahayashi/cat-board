import CatAPIClient
import CBModel
import Foundation

public actor MockCatImageURLRepository: CatImageURLRepositoryProtocol {
    private let apiClient: CatAPIClientProtocol
    private var loadedImageURLs: [CatImageURLModel] = []
    private var refillTask: Task<Void, Never>?

    private let maxLoadedURLCount = 300
    private let loadedURLThreshold = 100
    private let apiFetchBatchSize = 10

    public init(apiClient: CatAPIClientProtocol = MockCatAPIClient()) {
        self.apiClient = apiClient
        Task {
            await self.initializeLoadedImageURLs()
        }
    }

    deinit {
        refillTask?.cancel()
    }

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
                startBackgroundURLRefillLoadedURLs()
            }

            return provided
        }

        // キャッシュが不足している場合
        // 1. 利用可能なキャッシュを全て提供
        let available = try await getImageURLsFromLoadedURLs(count: loadedImageURLs.count)
        // 2. 残りをAPIから直接取得
        let remaining = try await apiClient.fetchImageURLs(
            totalCount: count - available.count,
            batchSize: apiFetchBatchSize
        )
        // 3. 補充を開始
        startBackgroundURLRefillLoadedURLs()

        print(
            "URL供給完了: loadedImageURLsから\(available.count)枚 + APIから\(remaining.count)枚 = 合計\(available.count + remaining.count)枚"
        )
        return available + remaining
    }

    private func getImageURLsFromLoadedURLs(count: Int) async throws -> [CatImageURLModel] {
        let actualCount = min(count, loadedImageURLs.count)
        let provided = Array(loadedImageURLs.prefix(actualCount))
        loadedImageURLs = Array(loadedImageURLs.dropFirst(actualCount))
        print("loadedImageURLsから提供: \(actualCount)枚提供（残り\(loadedImageURLs.count)枚）")
        return provided
    }

    private func initializeLoadedImageURLs() async {
        print("初期URL読み込み開始: 目標\(maxLoadedURLCount)枚")
        do {
            let loaded = try await apiClient.fetchImageURLs(totalCount: maxLoadedURLCount, batchSize: apiFetchBatchSize)
            loadedImageURLs = loaded
            print("初期URL読み込み完了: \(loaded.count)枚")
        } catch {
            print("初期URL読み込み失敗: \(error.localizedDescription)")
            loadedImageURLs = []
        }
    }

    private func startBackgroundURLRefillLoadedURLs() {
        guard refillTask == nil else { return }
        guard loadedImageURLs.count <= loadedURLThreshold else {
            print("loadedImageURLs補充不要: 現在\(loadedImageURLs.count)枚(閾値\(loadedURLThreshold)枚)")
            return
        }

        refillTask = Task { [self] in
            do {
                while loadedImageURLs.count <= loadedURLThreshold {
                    let neededToLoad = maxLoadedURLCount - loadedImageURLs.count
                    print(
                        "loadedImageURLs補充開始: 現在\(loadedImageURLs.count)枚 → 目標\(maxLoadedURLCount)枚(\(neededToLoad)枚追加予定)"
                    )

                    let fetched = try await apiClient.fetchImageURLs(
                        totalCount: neededToLoad,
                        batchSize: apiFetchBatchSize
                    )
                    loadedImageURLs += fetched
                    print("APIからloadedImageURLsへ補充: \(fetched.count)枚追加 → 現在\(loadedImageURLs.count)枚")
                }
            } catch {
                print("loadedImageURLsのバックグラウンド補充に失敗: \(error.localizedDescription)")
            }
            refillTask = nil
        }
    }
}
