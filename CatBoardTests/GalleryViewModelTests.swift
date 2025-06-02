import CatAPIClient
import CatImageLoader
import CatImageScreener
import CatImageURLRepository
import XCTest

@testable import CatBoardApp
import CBModel

@MainActor
final class GalleryViewModelTests: XCTestCase {
    var viewModel: GalleryViewModel!
    var mockLoader: MockCatImageLoader!
    var mockRepository: MockCatImageURLRepository!
    var mockScreener: MockCatImageScreener!

    override func setUp() {
        super.setUp()
        mockRepository = MockCatImageURLRepository()
    }

    override func tearDown() {
        viewModel = nil
        mockLoader = nil
        mockRepository = nil
        mockScreener = nil
        super.tearDown()
    }

    private func setupViewModel(
        mockImages: [CatImageURLModel] = TestResources.createMockCatImageURLModels(count: 10),
        error: Error? = nil
    ) {
        mockScreener = MockCatImageScreener(mockImages: mockImages, error: error)
        mockLoader = MockCatImageLoader(screener: mockScreener)
        viewModel = GalleryViewModel(repository: mockRepository, loader: mockLoader)
    }

    private func waitForAsyncOperation() async {
        try? await Task.sleep(nanoseconds: 1_000_000_000)
    }

    /// 初期画像の読み込みが正しく行われることを確認する
    func testLoadInitialImages() async {
        setupViewModel()

        XCTAssertTrue(viewModel.imageURLsToShow.isEmpty)
        XCTAssertFalse(viewModel.isInitializing)

        viewModel.loadInitialImages()
        XCTAssertTrue(viewModel.isInitializing)

        await waitForAsyncOperation()

        XCTAssertFalse(viewModel.isInitializing)
        XCTAssertEqual(viewModel.imageURLsToShow.count, GalleryViewModel.targetInitialDisplayCount)
    }

    /// 追加の画像が正しく取得されることを確認する
    func testFetchAdditionalImages() async {
        setupViewModel(mockImages: TestResources.createMockCatImageURLModels(count: 20))

        viewModel.loadInitialImages()
        await waitForAsyncOperation()
        let initialCount = viewModel.imageURLsToShow.count

        await viewModel.fetchAdditionalImages()

        XCTAssertEqual(viewModel.imageURLsToShow.count, initialCount + GalleryViewModel.batchDisplayCount)
        XCTAssertFalse(viewModel.isAdditionalFetching)
    }

    /// 初期化中に追加画像の取得が行われないことを確認する
    func testFetchAdditionalImagesWhenLoading() async {
        setupViewModel()

        viewModel.loadInitialImages()
        await viewModel.fetchAdditionalImages()

        XCTAssertEqual(viewModel.imageURLsToShow.count, 0)
    }

    /// 表示中の画像が正しくクリアされることを確認する
    func testClearDisplayedImages() async {
        setupViewModel()

        viewModel.loadInitialImages()
        await waitForAsyncOperation()
        XCTAssertFalse(viewModel.imageURLsToShow.isEmpty)

        viewModel.clearDisplayedImages()

        XCTAssertTrue(viewModel.imageURLsToShow.isEmpty)
        XCTAssertNil(viewModel.errorMessage)
    }

    /// 最大画像数（300枚）に達した場合、画像をクリアして再読み込みすることを確認する
    func testMaxImageCountReached() async {
        setupViewModel(
            mockImages: TestResources
                .createMockCatImageURLModels(count: GalleryViewModel.maxImageCount + 10)
        )

        // 初期画像を読み込む
        viewModel.loadInitialImages()
        await waitForAsyncOperation()
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
        setupViewModel(mockImages: TestResources.createMockCatImageURLModels(count: 5))

        viewModel.loadInitialImages()
        await waitForAsyncOperation()

        XCTAssertEqual(viewModel.imageURLsToShow.count, GalleryViewModel.targetInitialDisplayCount)
        XCTAssertFalse(viewModel.isInitializing)
    }

    /// スクリーニングでエラーが発生した場合の動作を確認する
    func testLoadImagesWithScreeningError() async {
        let error = NSError(domain: "test", code: -1, userInfo: [NSLocalizedDescriptionKey: "Screening failed"])
        let mockImages = TestResources.createMockCatImageURLModels(count: 5)
        setupViewModel(mockImages: mockImages, error: error)

        viewModel.loadInitialImages()
        await waitForAsyncOperation()

        // エラーが発生した場合、エラーメッセージが設定され、画像が空になることを確認
        XCTAssertTrue(viewModel.imageURLsToShow.isEmpty)
        XCTAssertFalse(viewModel.isInitializing)
        XCTAssertEqual(viewModel.errorMessage, "Screening failed")
    }
}
