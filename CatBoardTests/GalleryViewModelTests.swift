import XCTest
import Combine
import CBShared
import Infrastructure
@testable import CatBoard

@MainActor
final class GalleryViewModelTests: XCTestCase {
    private var viewModel: GalleryViewModel!

    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    // 初期状態のプロパティ値が正しいことを確認するテスト
    func testInitialState() {
        XCTAssertTrue(viewModel.imageURLsToShow.isEmpty, "catImagesは初期状態で空")
        XCTAssertNil(viewModel.errorMessage, "errorMessageは初期状態でnil")
        XCTAssertFalse(viewModel.isLoading, "isLoadingは初期状態でfalse")
    }
}
