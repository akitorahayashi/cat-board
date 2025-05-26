import CBModel
import SwiftData
import SwiftUI

@main
struct CatBoardApp: App {
    let modelContainer: ModelContainer

    init() {
        do {
            let schema = Schema([CatImageURLEntity.self])
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            CatImageGallery(modelContainer: modelContainer)
        }
    }
}
