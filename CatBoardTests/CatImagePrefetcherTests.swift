import CatAPIClient
import CatImageLoader
import CatImageScreener
import CatImageURLRepository
import CatImagePrefetcher
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
        mockRepository = MockCatImageURLRepository()
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
    func testGetPrefetchedCount_初期状態は0() async {
        let count = await prefetcher.getPrefetchedCount()
        XCTAssertEqual(count, 0)
    }

    /// 初期状態では画像を取得できないことを確認
    func testGetPrefetchedImages_初期状態は空配列() async {
        let images = await prefetcher.getPrefetchedImages(imageCount: 5)
        XCTAssertTrue(images.isEmpty)
    }

    /// プリフェッチを実行すると画像が取得できることを確認
    func testStartPrefetchingIfNeeded_プリフェッチが実行される() async {
        let testImageURLs = [
            CatImageURLModel(imageURL: "https://example.com/image1.jpg"),
            CatImageURLModel(imageURL: "https://example.com/image2.jpg"),
        ]
        mockRepository = MockCatImageURLRepository(mockImageURLs: testImageURLs)
        prefetcher = CatImagePrefetcher(
            repository: mockRepository,
            imageLoader: mockLoader,
            screener: mockScreener
        )

        await prefetcher.startPrefetchingIfNeeded()

        let count = await prefetcher.getPrefetchedCount()
        XCTAssertGreaterThan(count, 0)
    }

    /// 指定した枚数分の画像を取得できることを確認
    func testGetPrefetchedImages_指定した枚数分取得できる() async {
        let testImageURLs = [
            CatImageURLModel(imageURL: "https://example.com/image1.jpg"),
            CatImageURLModel(imageURL: "https://example.com/image2.jpg"),
            CatImageURLModel(imageURL: "https://example.com/image3.jpg"),
        ]
        mockRepository = MockCatImageURLRepository(mockImageURLs: testImageURLs)
        prefetcher = CatImagePrefetcher(
            repository: mockRepository,
            imageLoader: mockLoader,
            screener: mockScreener
        )

        await prefetcher.startPrefetchingIfNeeded()

        let images = await prefetcher.getPrefetchedImages(imageCount: 2)
        XCTAssertEqual(images.count, 2)

        let remainingCount = await prefetcher.getPrefetchedCount()
        XCTAssertEqual(remainingCount, 1)
    }

    /// プリフェッチの重複実行を防止できることを確認
    func testStartPrefetchingIfNeeded_重複実行は無視される() async {
        let testImageURLs = [
            CatImageURLModel(imageURL: "https://example.com/image1.jpg"),
            CatImageURLModel(imageURL: "https://example.com/image2.jpg"),
        ]
        mockRepository = MockCatImageURLRepository(mockImageURLs: testImageURLs)
        prefetcher = CatImagePrefetcher(
            repository: mockRepository,
            imageLoader: mockLoader,
            screener: mockScreener
        )

        await prefetcher.startPrefetchingIfNeeded()
        await prefetcher.startPrefetchingIfNeeded()

        let count = await prefetcher.getPrefetchedCount()
        XCTAssertGreaterThan(count, 0)
    }

    /// エラー発生時も安全に処理できることを確認
    func testStartPrefetchingIfNeeded_エラー発生時も安全に処理される() async {
        mockRepository = MockCatImageURLRepository(error: NSError(domain: "test", code: -1))
        prefetcher = CatImagePrefetcher(
            repository: mockRepository,
            imageLoader: mockLoader,
            screener: mockScreener
        )

        await prefetcher.startPrefetchingIfNeeded()

        let count = await prefetcher.getPrefetchedCount()
        XCTAssertEqual(count, 0)
    }
}
