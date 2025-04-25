import ComposableArchitecture
import XCTest

@testable import CatBoard

@MainActor
final class CoordinatorReducerTests: XCTestCase {
    func testInitialState() async {
        let store = TestStore(initialState: CoordinatorReducer.State()) {
            CoordinatorReducer()
        }
        XCTAssertNotNil(store.state.gallery)
    }
} 
