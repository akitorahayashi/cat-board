import SwiftData
import SwiftUI
import ComposableArchitecture

@main
struct CatBoardApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @State var store = Store(initialState: CoordinatorReducer.State()) {
        CoordinatorReducer()
    }

    var body: some Scene {
        WindowGroup {
            CatImageGallery(store: self.store.scope(state: \.gallery, action: \.gallery))
        }
        .modelContainer(sharedModelContainer)
    }
}
