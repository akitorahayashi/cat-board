import CatAPIClient
import CatImageLoader
import CatImagePrefetcher
import CatImageScreener
import CatImageURLRepository
import CBModel
import XCTest

@testable import CatBoardApp

@MainActor
final class GalleryViewModelTests: XCTestCase {
    var viewModel: GalleryViewModel!
    var mockLoader: MockCatImageLoader!
    var mockRepository: MockCatImageURLRepository!
    var mockScreener: MockCatImageScreener!
    var prefetcher: CatImagePrefetcher!

    override func setUp() {
        super.setUp()
        mockRepository = MockCatImageURLRepository(apiClient: MockCatAPIClient())
        mockScreener = MockCatImageScreener()
        mockLoader = MockCatImageLoader()
        prefetcher = CatImagePrefetcher(
            repository: mockRepository,
            imageLoader: mockLoader,
            screener: mockScreener
        )
        viewModel = GalleryViewModel(
            repository: mockRepository,
            imageLoader: mockLoader,
            screener: mockScreener,
            prefetcher: prefetcher
        )
    }

    override func tearDown() {
        viewModel = nil
        mockLoader = nil
        mockRepository = nil
        mockScreener = nil
        prefetcher = nil
        super.tearDown()
    }

    /// 初期画像の読み込みが正しく行われることを確認する
    func testLoadInitialImages() async {
        XCTAssertTrue(viewModel.imageURLsToShow.isEmpty)

        viewModel.loadInitialImages()
        
        // 画像の読み込みが完了するまで待機
        var attempts = 0
        while viewModel.imageURLsToShow.count < GalleryViewModel.targetInitialDisplayCount && attempts < 50 {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒待機
            attempts += 1
        }

        XCTAssertEqual(viewModel.imageURLsToShow.count, GalleryViewModel.targetInitialDisplayCount)
    }

    /// 追加の画像が正しく取得されることを確認する
    func testFetchAdditionalImages() async {
        viewModel.loadInitialImages()
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        let initialCount = viewModel.imageURLsToShow.count

        await viewModel.fetchAdditionalImages()

        XCTAssertEqual(viewModel.imageURLsToShow.count, initialCount + GalleryViewModel.batchDisplayCount)
        XCTAssertFalse(viewModel.isAdditionalFetching)
    }

    /// 追加取得中に新しい追加取得が行われないことを確認する
    func testFetchAdditionalImagesDuringFetching() async {
        // 初期画像を読み込む
        viewModel.loadInitialImages()
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        // 最初の追加取得を開始
        let initialCount = viewModel.imageURLsToShow.count
        let firstFetch = Task { await viewModel.fetchAdditionalImages() }
        
        // 追加取得中に別の追加取得を試みる
        await viewModel.fetchAdditionalImages()
        
        // 最初の追加取得が完了するのを待つ
        await firstFetch.value
        
        // 追加取得が1回だけ行われたことを確認
        XCTAssertEqual(viewModel.imageURLsToShow.count, initialCount + GalleryViewModel.batchDisplayCount)
    }

    /// 表示中の画像が正しくクリアされることを確認する
    func testClearDisplayedImages() async {
        viewModel.loadInitialImages()
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        XCTAssertFalse(viewModel.imageURLsToShow.isEmpty)

        viewModel.clearDisplayedImages()

        XCTAssertTrue(viewModel.imageURLsToShow.isEmpty)
        XCTAssertNil(viewModel.errorMessage)
    }

    /// 最大画像数（300枚）に達した場合、画像をクリアして再読み込みすることを確認する
    func testMaxImageCountReached() async {
        // 初期画像を読み込む
        viewModel.loadInitialImages()
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        let initialCount = viewModel.imageURLsToShow.count

        // 最大画像数に達するまで追加取得
        for _ in 0 ..< (GalleryViewModel.maxImageCount / GalleryViewModel.batchDisplayCount) {
            await viewModel.fetchAdditionalImages()
        }

        // 最大画像数を超えた場合の動作を確認
        await viewModel.fetchAdditionalImages()

        // 画像がクリアされ、再読み込みが開始されていることを確認
        XCTAssertTrue(viewModel.isInitializing)
        XCTAssertFalse(viewModel.isAdditionalFetching)
        XCTAssertLessThanOrEqual(viewModel.imageURLsToShow.count, GalleryViewModel.maxImageCount)
    }

    /// スクリーニング後の画像が正しく表示されることを確認する
    func testLoadImagesWithScreening() async {
        viewModel.loadInitialImages()
        try? await Task.sleep(nanoseconds: 1_000_000_000)

        XCTAssertEqual(viewModel.imageURLsToShow.count, GalleryViewModel.targetInitialDisplayCount)
        XCTAssertFalse(viewModel.isInitializing)
    }

    /// スクリーニングでエラーが発生した場合の動作を確認する
    func testLoadImagesWithScreeningError() async {
        let error = NSError(domain: "test", code: -1, userInfo: [NSLocalizedDescriptionKey: "Screening failed"])
        mockScreener = MockCatImageScreener(error: error)
        mockLoader = MockCatImageLoader()
        prefetcher = CatImagePrefetcher(
            repository: mockRepository,
            imageLoader: mockLoader,
            screener: mockScreener
        )
        viewModel = GalleryViewModel(
            repository: mockRepository,
            imageLoader: mockLoader,
            screener: mockScreener,
            prefetcher: prefetcher
        )

        viewModel.loadInitialImages()
        try? await Task.sleep(nanoseconds: 1_000_000_000)

        // エラーが発生した場合、エラーメッセージが設定され、画像が空になることを確認
        XCTAssertTrue(viewModel.imageURLsToShow.isEmpty)
        XCTAssertFalse(viewModel.isInitializing)
        XCTAssertEqual(viewModel.errorMessage, "Screening failed")
    }
}
