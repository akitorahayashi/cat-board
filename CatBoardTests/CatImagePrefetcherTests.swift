import CatAPIClient
import CatImageLoader
import CatImagePrefetcher
import CatImageScreener
import CatImageURLRepository
import CatURLImageModel
import SwiftData
import XCTest

@testable import CatBoardApp

final class CatImagePrefetcherTests: XCTestCase {
    private var mockRepository: MockCatImageURLRepository!
    private var mockLoader: MockCatImageLoader!
    private var mockScreener: MockCatImageScreener!
    private var modelContainer: ModelContainer!
    private var prefetcher: CatImagePrefetcher!

    override func setUp() throws {
        super.setUp()
        mockRepository = MockCatImageURLRepository(apiClient: MockCatAPIClient())
        mockLoader = MockCatImageLoader()
        mockScreener = MockCatImageScreener()
        modelContainer = try ModelContainer(for: PrefetchedCatImageURL.self)
        prefetcher = CatImagePrefetcher(
            repository: mockRepository,
            imageLoader: mockLoader,
            screener: mockScreener,
            modelContainer: modelContainer
        )
    }

    override func tearDown() {
        mockRepository = nil
        mockLoader = nil
        mockScreener = nil
        modelContainer = nil
        prefetcher = nil
        super.tearDown()
    }

    /// 初期状態ではプリフェッチされた画像が0枚であることを確認
    func testInitialPrefetchedCount() async throws {
        let count = try await prefetcher.getPrefetchedCount()
        XCTAssertEqual(count, 0)
    }

    /// 初期状態では画像を取得できないことを確認
    func testInitialPrefetchedImages() async throws {
        let images = try await prefetcher.getPrefetchedImages(imageCount: 5)
        XCTAssertTrue(images.isEmpty)
    }

    /// プリフェッチを実行すると画像が取得できることを確認
    func testStartPrefetching() async throws {
        try await prefetcher.startPrefetchingIfNeeded()
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒待機

        let count = try await prefetcher.getPrefetchedCount()
        XCTAssertGreaterThan(count, 0)
    }

    /// 指定した枚数分の画像を取得できることを確認
    func testGetRequestedImageCount() async throws {
        try await prefetcher.startPrefetchingIfNeeded()
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒待機

        let images = try await prefetcher.getPrefetchedImages(imageCount: 2)
        XCTAssertEqual(images.count, 2)

        let remainingCount = try await prefetcher.getPrefetchedCount()
        XCTAssertGreaterThan(remainingCount, 0)
    }

    /// プリフェッチの重複実行を防止できることを確認
    func testIgnoreDuplicatePrefetching() async throws {
        try await prefetcher.startPrefetchingIfNeeded()
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒待機
        try await prefetcher.startPrefetchingIfNeeded()
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒待機

        let count = try await prefetcher.getPrefetchedCount()
        XCTAssertGreaterThan(count, 0)
    }

    /// エラー発生時も安全に処理できることを確認
    func testHandlePrefetchingError() async throws {
        // エラーを発生させるMockCatAPIClientを使用
        mockRepository = MockCatImageURLRepository(
            apiClient: MockCatAPIClient(error: NSError(domain: "test", code: -1))
        )
        prefetcher = CatImagePrefetcher(
            repository: mockRepository,
            imageLoader: mockLoader,
            screener: mockScreener,
            modelContainer: modelContainer
        )

        try await prefetcher.startPrefetchingIfNeeded()
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒待機

        let count = try await prefetcher.getPrefetchedCount()
        XCTAssertEqual(count, 0)
    }
}
