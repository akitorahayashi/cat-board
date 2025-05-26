import CatAPIClient
@testable import CatBoard
import CatImageURLRepository
import CBModel
import Combine
import XCTest

@MainActor
final class GalleryViewModelTests: XCTestCase {
    private var viewModel: GalleryViewModel!

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }
}
