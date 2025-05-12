import ComposableArchitecture
import SwiftUI
import TieredGridLayout

struct CatImageGallery: View {
    @State var store: StoreOf<GalleryReducer>

    var body: some View {
        WithPerceptionTracking {
            NavigationView {
                Group {
                    ScrollView {
                        VStack {
                            if let errorMessage = store.errorMessage {
                                Text("エラーが発生しました： \(errorMessage)")
                                    .rotationEffect(.degrees(180))
                                    .padding()
                            } else {
                                galleryGrid
                            }
                        }
                    }
                    .rotationEffect(.degrees(180))
                }
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("Cat Board")
                            .font(.headline)
                    }
                }
                .task {
                    await store.send(.onAppear).finish()
                }
            }
        }
    }

    @ViewBuilder
    private var galleryGrid: some View {
        TieredGridLayout {
            ForEach(store.catImages) { image in
                SquareGalleryImageAsync(url: URL(string: image.imageURL))
                    .padding(2)
                    .transition(.opacity)
                    .rotationEffect(.degrees(180))
            }
        }
        .padding(2)
        .animation(.default, value: store.catImages)
    }
}
