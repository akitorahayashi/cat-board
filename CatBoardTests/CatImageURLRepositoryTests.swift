import CatAPIClient
import CatImageURLRepository
import CBModel
import SwiftData
import XCTest

@MainActor
final class CatImageURLRepositoryTests: XCTestCase {
    private var repository: CatImageURLRepository!
    private var modelContainer: ModelContainer!
    private var mockAPIClient: MockCatAPIClient!

    override func setUpWithError() throws {
        // テスト用のSwiftDataコンテナを作成
        let schema = Schema([CatImageURLEntity.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])

        mockAPIClient = MockCatAPIClient()
        // モックデータの設定
        mockAPIClient.mockImageURLs = TestResources.createMockCatImageURLModels(count: 3)
        repository = CatImageURLRepository(modelContainer: modelContainer, apiClient: mockAPIClient)
    }

    override func tearDown() {
        repository = nil
        modelContainer = nil
        mockAPIClient = nil
    }

    // APIから画像URLを取得する機能を確認する
    func testGetNextImageURLsFromAPI() async throws {
        // テスト実行
        let result = try await repository.getNextImageURLs(count: 2)

        // 検証
        XCTAssertEqual(result.count, 2, "要求した数の画像URLが取得できる")
        XCTAssertNotNil(result[0].imageURL, "最初の画像URLが存在する")
        XCTAssertNotNil(result[1].imageURL, "2番目の画像URLが存在する")
    }

    // キャッシュから画像URLを取得する機能を確認する
    func testGetNextImageURLsFromCache() async throws {
        // 最初の取得でキャッシュに保存
        let firstResult = try await repository.getNextImageURLs(count: 2)

        // キャッシュから取得
        let secondResult = try await repository.getNextImageURLs(count: 1)

        // 検証
        XCTAssertEqual(secondResult.count, 1, "キャッシュから要求した数の画像URLが取得できる")
        XCTAssertEqual(secondResult[0].imageURL, firstResult[0].imageURL, "キャッシュから取得した画像URLが最初の取得結果と一致する")
    }

    // キャッシュが空になった時の自動補充を確認する
    func testAutoRefillWhenCacheEmpty() async throws {
        // キャッシュを空にする
        let firstResult = try await repository.getNextImageURLs(count: 3)
        XCTAssertEqual(firstResult.count, 3, "最初の取得で全キャッシュを使用")

        // 新しい画像URLを設定
        let newImages = TestResources.createMockCatImageURLModels(count: 3)
        mockAPIClient.mockImageURLs = newImages

        // キャッシュが空の状態で取得
        let secondResult = try await repository.getNextImageURLs(count: 1)

        // 検証
        XCTAssertEqual(secondResult.count, 1, "要求した数の画像URLが取得できる")
        XCTAssertEqual(secondResult[0].imageURL, newImages[0].imageURL, "新しい画像URLが取得できる")
    }

    // キャッシュの残数が少なくなった時の自動補充を確認する
    func testAutoRefillWhenCacheLow() async throws {
        // キャッシュを少なくする
        let firstResult = try await repository.getNextImageURLs(count: 2)
        XCTAssertEqual(firstResult.count, 2, "最初の取得でキャッシュを減らす")

        // 新しい画像URLを設定
        let newImages = TestResources.createMockCatImageURLModels(count: 3)
        mockAPIClient.mockImageURLs = newImages

        // 残り1つのキャッシュを使用
        let secondResult = try await repository.getNextImageURLs(count: 1)

        // 検証
        XCTAssertEqual(secondResult.count, 1, "要求した数の画像URLが取得できる")
        XCTAssertEqual(secondResult[0].imageURL, firstResult[0].imageURL, "残りのキャッシュから取得できる")

        // 自動補充後の取得を確認
        let thirdResult = try await repository.getNextImageURLs(count: 1)
        XCTAssertEqual(thirdResult.count, 1, "自動補充後に要求した数の画像URLが取得できる")
        XCTAssertEqual(thirdResult[0].imageURL, newImages[0].imageURL, "自動補充された新しい画像URLが取得できる")
    }

    // 自動補充時のAPIエラーを確認する
    func testAutoRefillAPIError() async {
        // キャッシュを空にする
        _ = try? await repository.getNextImageURLs(count: 3)

        // エラーを設定
        mockAPIClient.fetchImageURLsError = NSError(domain: "TestError", code: -1, userInfo: nil)

        // キャッシュが空の状態で取得を試みる
        do {
            _ = try await repository.getNextImageURLs(count: 1)
            XCTFail("エラーが発生するはず")
        } catch {
            // エラーが発生したことを確認
            XCTAssertNotNil(error)
        }
    }

    // APIエラー時の動作を確認する
    func testAPIError() async {
        // エラーを設定
        mockAPIClient.fetchImageURLsError = NSError(domain: "TestError", code: -1, userInfo: nil)

        // エラーが発生することを確認
        do {
            _ = try await repository.getNextImageURLs(count: 1)
            XCTFail("エラーが発生するはず")
        } catch {
            // エラーが発生したことを確認
            XCTAssertNotNil(error)
        }
    }
}
