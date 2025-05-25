@testable import CatBoard
import CBModel
import Combine
import CatAPIClient
import CatImageURLRepository
import XCTest

@MainActor
final class GalleryViewModelTests: XCTestCase {
    private var viewModel: GalleryViewModel!

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }
}
