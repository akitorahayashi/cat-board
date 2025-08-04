import CatAPIClient
import CatImageURLRepository
import SwiftData
import XCTest

@MainActor
final class CatImageURLRepositoryTests: XCTestCase {
    private var repository: CatImageURLRepository!
    private var modelContainer: ModelContainer!
    private var mockAPIClient: MockCatAPIClient!

    override func setUpWithError() throws {
        let schema = Schema([StoredCatImageURL.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])

        mockAPIClient = MockCatAPIClient()
        repository = CatImageURLRepository(modelContainer: modelContainer, apiClient: mockAPIClient)
    }

    override func tearDown() {
        repository = nil
        modelContainer = nil
        mockAPIClient = nil
    }

    /// APIから画像URLを取得する機能を確認する
    func testGetNextImageURLsFromAPI() async throws {
        let result = try await repository.getNextImageURLs(count: 2)

        XCTAssertEqual(result.count, 2)
        XCTAssertNotNil(result[0])
        XCTAssertNotNil(result[1])
    }

    /// キャッシュから画像URLを取得する機能を確認する
    func testGetNextImageURLsFromCache() async throws {
        let firstResult = try await repository.getNextImageURLs(count: 2)
        let secondResult = try await repository.getNextImageURLs(count: 1)

        XCTAssertEqual(secondResult.count, 1)
        XCTAssertEqual(secondResult[0], firstResult[0])
    }

    /// キャッシュが空になった時の自動補充を確認する
    func testAutoRefillWhenCacheEmpty() async throws {
        let firstResult = try await repository.getNextImageURLs(count: 3)
        XCTAssertEqual(firstResult.count, 3)

        mockAPIClient = MockCatAPIClient()
        repository = CatImageURLRepository(modelContainer: modelContainer, apiClient: mockAPIClient)

        let secondResult = try await repository.getNextImageURLs(count: 1)

        XCTAssertEqual(secondResult.count, 1)
        XCTAssertNotNil(secondResult[0])
    }

    /// キャッシュの残数が少なくなった時の自動補充を確認する
    func testAutoRefillWhenCacheLow() async throws {
        let firstResult = try await repository.getNextImageURLs(count: 2)
        XCTAssertEqual(firstResult.count, 2)

        mockAPIClient = MockCatAPIClient()
        repository = CatImageURLRepository(modelContainer: modelContainer, apiClient: mockAPIClient)

        let secondResult = try await repository.getNextImageURLs(count: 1)

        XCTAssertEqual(secondResult.count, 1)
        XCTAssertEqual(secondResult[0], firstResult[0])

        let thirdResult = try await repository.getNextImageURLs(count: 1)
        XCTAssertEqual(thirdResult.count, 1)
        XCTAssertNotNil(thirdResult[0])
    }

    /// 自動補充時のAPIエラーを確認する
    func testAutoRefillAPIError() async {
        _ = try? await repository.getNextImageURLs(count: 3)

        let error = NSError(domain: "TestError", code: -1, userInfo: nil)
        mockAPIClient = MockCatAPIClient(error: error)
        repository = CatImageURLRepository(modelContainer: modelContainer, apiClient: mockAPIClient)

        do {
            _ = try await repository.getNextImageURLs(count: 1)
            XCTFail("エラーが発生していない")
        } catch {
            XCTAssertNotNil(error)
        }
    }

    /// APIエラー時の動作を確認する
    func testAPIError() async {
        let error = NSError(domain: "TestError", code: -1, userInfo: nil)
        mockAPIClient = MockCatAPIClient(error: error)
        repository = CatImageURLRepository(modelContainer: modelContainer, apiClient: mockAPIClient)

        do {
            _ = try await repository.getNextImageURLs(count: 1)
            XCTFail("エラーが発生していない")
        } catch {
            XCTAssertNotNil(error)
        }
    }
}
