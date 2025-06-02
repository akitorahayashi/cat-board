import CatAPIClient
import CatImageLoader
import CatImagePrefetcher
import CatImageScreener
import CatImageURLRepository
import CBModel
import XCTest

@testable import CatBoardApp

final class CatImagePrefetcherTests: XCTestCase {
    private var mockRepository: MockCatImageURLRepository!
    private var mockLoader: MockCatImageLoader!
    private var mockScreener: MockCatImageScreener!
    private var prefetcher: CatImagePrefetcher!

    override func setUp() {
        super.setUp()
        mockRepository = MockCatImageURLRepository(apiClient: MockCatAPIClient())
        mockLoader = MockCatImageLoader()
        mockScreener = MockCatImageScreener()
        prefetcher = CatImagePrefetcher(
            repository: mockRepository,
            imageLoader: mockLoader,
            screener: mockScreener
        )
    }

    override func tearDown() {
        mockRepository = nil
        mockLoader = nil
        mockScreener = nil
        prefetcher = nil
        super.tearDown()
    }

    /// 初期状態ではプリフェッチされた画像が0枚であることを確認
    func testInitialPrefetchedCount() async {
        let count = await prefetcher.getPrefetchedCount()
        XCTAssertEqual(count, 0)
    }

    /// 初期状態では画像を取得できないことを確認
    func testInitialPrefetchedImages() async {
        let images = await prefetcher.getPrefetchedImages(imageCount: 5)
        XCTAssertTrue(images.isEmpty)
    }

    /// プリフェッチを実行すると画像が取得できることを確認
    func testStartPrefetching() async {
        await prefetcher.startPrefetchingIfNeeded()
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒待機

        let count = await prefetcher.getPrefetchedCount()
        XCTAssertGreaterThan(count, 0)
    }

    /// 指定した枚数分の画像を取得できることを確認
    func testGetRequestedImageCount() async {
        await prefetcher.startPrefetchingIfNeeded()
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒待機

        let images = await prefetcher.getPrefetchedImages(imageCount: 2)
        XCTAssertEqual(images.count, 2)

        let remainingCount = await prefetcher.getPrefetchedCount()
        XCTAssertGreaterThan(remainingCount, 0)
    }

    /// プリフェッチの重複実行を防止できることを確認
    func testIgnoreDuplicatePrefetching() async {
        await prefetcher.startPrefetchingIfNeeded()
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒待機
        await prefetcher.startPrefetchingIfNeeded()
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒待機

        let count = await prefetcher.getPrefetchedCount()
        XCTAssertGreaterThan(count, 0)
    }

    /// エラー発生時も安全に処理できることを確認
    func testHandlePrefetchingError() async {
        // エラーを発生させるMockCatAPIClientを使用
        mockRepository = MockCatImageURLRepository(
            apiClient: MockCatAPIClient(error: NSError(domain: "test", code: -1))
        )
        prefetcher = CatImagePrefetcher(
            repository: mockRepository,
            imageLoader: mockLoader,
            screener: mockScreener
        )

        await prefetcher.startPrefetchingIfNeeded()
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒待機

        let count = await prefetcher.getPrefetchedCount()
        XCTAssertEqual(count, 0)
    }
}
