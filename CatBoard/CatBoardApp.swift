import ComposableArchitecture
import SwiftData
import SwiftUI

@main
struct CatBoardApp: App {
    @State var coordinatorStore: StoreOf<CoordinatorReducer>

    init() {
        #if DEBUG
        // デバッグビルドの場合、imageClientをmockValueで上書き
        let coordinatorStore = Store(initialState: CoordinatorReducer.State()) {
            CoordinatorReducer()
                ._printChanges()
        } withDependencies: { dependencies in
            dependencies.imageClient = .mockValue
        }
        _coordinatorStore = State(wrappedValue: coordinatorStore)
        #else
        // リリースビルドの場合は通常通り初期化
        let coordinatorStore = Store(initialState: CoordinatorReducer.State()) {
            CoordinatorReducer()
        }
        _coordinatorStore = State(wrappedValue: coordinatorStore)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            CatImageGallery(store: coordinatorStore.scope(state: \.gallery, action: \.gallery))
        }
    }
}
