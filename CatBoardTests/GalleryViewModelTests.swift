import XCTest

import CatAPIClient
import CatImageLoader
import CatImageURLRepository

@testable import CatBoardApp
import CBModel

@MainActor
final class GalleryViewModelTests: XCTestCase {
    private var viewModel: GalleryViewModel!
    private var mockRepository: MockCatImageURLRepository!
    private var mockLoader: MockCatImageLoader!

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

    // MARK: - テストケース

    // 初期状態の検証
    func testInitialState() {
        XCTAssertTrue(viewModel.imageURLsToShow.isEmpty, "初期状態では画像URLの配列が空")
        XCTAssertNil(viewModel.errorMessage, "初期状態ではエラーメッセージがnil")
        XCTAssertFalse(viewModel.isInitializing, "初期状態では初期化中ではない")
        XCTAssertFalse(viewModel.isAdditionalFetching, "初期状態では追加取得中ではない")
    }
}
