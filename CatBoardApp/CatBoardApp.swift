import CatAPIClient
import CatImageLoader
import CatImagePrefetcher
import CatImageScreener
import CatImageURLRepository
import CatURLImageModel
import SwiftData
import SwiftUI

@main
struct CatBoardApp: App {
    let modelContainer: ModelContainer
    let repository: CatImageURLRepositoryProtocol
    let imageLoader: CatImageLoaderProtocol
    let screener: CatImageScreenerProtocol
    let prefetcher: CatImagePrefetcherProtocol

    init() {
        // UIテスト実行時はモック依存関係を使用
        if ProcessInfo.processInfo.arguments.contains("--uitesting") {
            do {
                let schema = Schema([StoredCatImageURL.self, PrefetchedCatImageURL.self])
                let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])

                let mockAPIClient = MockCatAPIClient()
                screener = MockCatImageScreener()
                let mockImageLoader = MockCatImageLoader()
                
                imageLoader = mockImageLoader
                let mockRepository = MockCatImageURLRepository(apiClient: mockAPIClient)
                repository = mockRepository
                
                // エラーシミュレーション引数がある場合はエラーを設定
                if ProcessInfo.processInfo.arguments.contains("--simulate-error") {
                    Task {
                        await mockImageLoader.setError(NSError(
                            domain: "MockCatImageLoader",
                            code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "テスト用の画像読み込みエラーです"]
                        ))
                    }
                }
                
                prefetcher = NoopCatImagePrefetcher(
                    repository: repository,
                    imageLoader: imageLoader,
                    screener: screener
                )
            } catch {
                fatalError("テスト用の依存関係を初期化できませんでした: \(error)")
            }
        } else {
            // プロダクションの依存関係
            do {
                let schema = Schema([StoredCatImageURL.self, PrefetchedCatImageURL.self])
                let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
                modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])

                let imageClient = CatAPIClient()
                screener = CatImageScreener()
                imageLoader = CatImageLoader()
                repository = CatImageURLRepository(
                    modelContainer: modelContainer,
                    apiClient: imageClient
                )
                prefetcher = CatImagePrefetcher(
                    repository: repository,
                    imageLoader: imageLoader,
                    screener: screener,
                    modelContainer: modelContainer
                )
            } catch {
                fatalError("ModelContainerを初期化できませんでした: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            CatImageGallery(
                repository: repository,
                imageLoader: imageLoader,
                screener: screener,
                prefetcher: prefetcher
            )
            .modelContainer(modelContainer)
        }
    }
}
