@testable import CatBoard
import CBShared
import Combine
import Infrastructure
import XCTest

@MainActor
final class GalleryViewModelTests: XCTestCase {
    private var viewModel: GalleryViewModel!

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }
}
