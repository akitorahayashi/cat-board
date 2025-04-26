import ComposableArchitecture
import SwiftData
import SwiftUI

@main
struct CatBoardApp: App {
    @State var store = Store(initialState: CoordinatorReducer.State()) {
        CoordinatorReducer()
    }

    var body: some Scene {
        WindowGroup {
            CatImageGallery(store: store.scope(state: \.gallery, action: \.gallery))
        }
    }
}
