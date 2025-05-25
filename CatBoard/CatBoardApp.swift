import SwiftData
import SwiftUI
import CBModel

@main
struct CatBoardApp: App {
    var body: some Scene {
        WindowGroup {
            CatImageGalleryLauncher()
                .modelContainer(for: CatImageURLEntity.self)
        }
    }
}

struct CatImageGalleryLauncher: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        CatImageGallery(modelContext: modelContext)
    }
}
