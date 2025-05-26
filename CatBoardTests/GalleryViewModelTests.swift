import CatAPIClient
@testable import CatBoardApp
import CatImageURLRepository
import CatImageLoader
import CBModel
import XCTest

@MainActor
final class GalleryViewModelTests: XCTestCase {
    private var viewModel: GalleryViewModel!
    private var mockRepository: MockCatImageURLRepository!
    private var mockLoader: MockCatImageLoader!
    private let mockURLs = [
        "https://cdn2.thecatapi.com/images/MTY3ODIyMQ.jpg",
        "https://cdn2.thecatapi.com/images/1j6.jpg",
        "https://cdn2.thecatapi.com/images/2j6.jpg",
        "https://cdn2.thecatapi.com/images/3j6.jpg",
        "https://cdn2.thecatapi.com/images/4j6.jpg",
        "https://cdn2.thecatapi.com/images/5j6.jpg",
        "https://cdn2.thecatapi.com/images/6j6.jpg",
        "https://cdn2.thecatapi.com/images/7j6.jpg",
        "https://cdn2.thecatapi.com/images/8j6.jpg",
        "https://cdn2.thecatapi.com/images/9j6.jpg"
    ]

    override func setUp() {
        super.setUp()
        mockRepository = MockCatImageURLRepository()
        mockLoader = MockCatImageLoader()
        viewModel = GalleryViewModel(
            repository: mockRepository,
            loader: mockLoader
        )
    }

    override func tearDown() {
        viewModel = nil
        mockRepository = nil
        mockLoader = nil
        super.tearDown()
    }

    /// 初期状態の検証
    func testInitialState() {
        XCTAssertTrue(viewModel.imageURLsToShow.isEmpty)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isLoading)
    }

    /// 初期画像の読み込み成功時の検証
    func testLoadInitialImagesSuccess() async {
        let expectedImages = [
            CatImageURLModel(imageURL: mockURLs[0]),
            CatImageURLModel(imageURL: mockURLs[1])
        ]
        mockLoader.loadImagesWithScreeningResult = expectedImages

        viewModel.loadInitialImages()
        
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        XCTAssertEqual(viewModel.imageURLsToShow, expectedImages)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isLoading)
    }

    /// 初期画像の読み込み失敗時の検証
    func testLoadInitialImagesFailure() async {
        let expectedError = NSError(domain: "TestError", code: -1, userInfo: nil)
        mockLoader.loadImagesWithScreeningError = expectedError

        viewModel.loadInitialImages()
        
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        XCTAssertTrue(viewModel.imageURLsToShow.isEmpty)
        XCTAssertEqual(viewModel.errorMessage, expectedError.localizedDescription)
        XCTAssertFalse(viewModel.isLoading)
    }

    /// 追加画像の読み込み成功時の検証
    func testFetchAdditionalImagesSuccess() async {
        let initialImages = [
            CatImageURLModel(imageURL: mockURLs[0]),
            CatImageURLModel(imageURL: mockURLs[1])
        ]
        let additionalImages = [
            CatImageURLModel(imageURL: mockURLs[2]),
            CatImageURLModel(imageURL: mockURLs[3])
        ]
        mockLoader.loadImagesWithScreeningResult = initialImages
        viewModel.loadInitialImages()
        
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        mockLoader.loadImagesWithScreeningResult = additionalImages

        await viewModel.fetchAdditionalImages()
        
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(viewModel.imageURLsToShow, initialImages + additionalImages)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isLoading)
    }

    /// 追加画像の読み込み失敗時の検証
    func testFetchAdditionalImagesFailure() async {
        let initialImages = [
            CatImageURLModel(imageURL: mockURLs[0]),
            CatImageURLModel(imageURL: mockURLs[1])
        ]
        mockLoader.loadImagesWithScreeningResult = initialImages
        viewModel.loadInitialImages()
        
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        let expectedError = NSError(domain: "TestError", code: -1, userInfo: nil)
        mockLoader.loadImagesWithScreeningError = expectedError

        await viewModel.fetchAdditionalImages()
        
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(viewModel.imageURLsToShow, initialImages)
        XCTAssertEqual(viewModel.errorMessage, expectedError.localizedDescription)
        XCTAssertFalse(viewModel.isLoading)
    }

    /// ローディング中の追加画像取得時の検証
    func testFetchAdditionalImagesWhenLoading() async {
        let initialImages = [
            CatImageURLModel(imageURL: mockURLs[0]),
            CatImageURLModel(imageURL: mockURLs[1])
        ]
        mockLoader.loadImagesWithScreeningResult = initialImages
        viewModel.loadInitialImages()
        
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        viewModel.isLoading = true
        
        await viewModel.fetchAdditionalImages()
        
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(viewModel.imageURLsToShow, initialImages)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.isLoading)
    }

    /// 画像のクリアと再読み込みの検証
    func testClearDisplayedImages() async {
        let initialImages = [
            CatImageURLModel(imageURL: mockURLs[0]),
            CatImageURLModel(imageURL: mockURLs[1])
        ]
        mockLoader.loadImagesWithScreeningResult = initialImages
        viewModel.loadInitialImages()
        
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        let newImages = [
            CatImageURLModel(imageURL: mockURLs[2]),
            CatImageURLModel(imageURL: mockURLs[3])
        ]
        mockLoader.loadImagesWithScreeningResult = newImages

        viewModel.clearDisplayedImages()
        
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(viewModel.imageURLsToShow, newImages)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isLoading)
    }

    /// 最大画像数の制限検証
    func testMaxImageCount() async {
        // 初期画像を設定（targetInitialDisplayCount枚）
        let initialImages = Array(repeating: CatImageURLModel(imageURL: mockURLs[0]), count: GalleryViewModel.targetInitialDisplayCount)
        mockLoader.loadImagesWithScreeningResult = initialImages
        viewModel.loadInitialImages()
        
        for _ in 0..<10 {
            if viewModel.imageURLsToShow.count == GalleryViewModel.targetInitialDisplayCount {
                break
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        
        // 画像が正しく読み込まれたことを確認
        XCTAssertEqual(viewModel.imageURLsToShow.count, GalleryViewModel.targetInitialDisplayCount)
        XCTAssertEqual(viewModel.imageURLsToShow.first?.imageURL, mockURLs[0])
        
        // 新しい画像を設定（batchDisplayCount枚）
        let newImages = Array(repeating: CatImageURLModel(imageURL: mockURLs[1]), count: GalleryViewModel.batchDisplayCount)
        mockLoader.loadImagesWithScreeningResult = newImages

        // 追加画像取得を試みる
        await viewModel.fetchAdditionalImages()
        
        for _ in 0..<10 {
            if viewModel.imageURLsToShow.count == GalleryViewModel.targetInitialDisplayCount + GalleryViewModel.batchDisplayCount {
                break
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        // 新しい画像が正しく表示されていることを確認
        XCTAssertEqual(viewModel.imageURLsToShow.count, GalleryViewModel.targetInitialDisplayCount + GalleryViewModel.batchDisplayCount)
        XCTAssertEqual(viewModel.imageURLsToShow.first?.imageURL, mockURLs[0]) // 最初の画像は変更されない
        XCTAssertEqual(viewModel.imageURLsToShow.last?.imageURL, mockURLs[1]) // 最後の画像が新しい画像
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isLoading)
    }
}
