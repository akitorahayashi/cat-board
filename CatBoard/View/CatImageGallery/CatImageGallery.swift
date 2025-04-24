import ComposableArchitecture
import SwiftUI
import TieredGridLayout

struct CatImageGallery: View {
    @State var store: StoreOf<GalleryReducer>

    var body: some View {
        NavigationView {
            ScrollView {
                if store.isLoading {
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                } else if let errorMessage = store.errorMessage {
                    Text("Error: \(errorMessage)")
                        .foregroundColor(.red)
                        .padding()
                } else if store.items.isEmpty {
                    Text("サーバーエラーが発生しました。")
                        .padding()
                } else {
                    TieredGridLayout(items: store.items) { image in
                        Button {
                            store.send(.imageTapped(image.id))
                        } label: {
                            AsyncImage(url: image.url) { phase in
                                if let img = phase.image {
                                    img.resizable()
                                        .aspectRatio(contentMode: .fill)
                                } else if phase.error != nil {
                                    Color.red
                                } else {
                                    Color.gray.opacity(0.3)
                                }
                            }
                            .border(Color.white, width: 2)
                            .clipped()
                        }
                    }
                    .padding(.horizontal, 2)

                    if store.canLoadMore, !store.isLoadingMore {
                        Button("Load More") {
                            store.send(.fetchImages)
                        }
                        .padding()
                    } else if store.isLoadingMore {
                        ProgressView().padding()
                    }
                }
            }
            .navigationTitle("Cat Gallery")
            .task {
                await store.send(.task).finish()
            }
            .refreshable {
                await store.send(.pullToRefresh).finish()
            }
        }
    }
}

#Preview {
    CatImageGallery(
        store: Store(initialState: GalleryReducer.State()) {
            GalleryReducer()
        }
    )
}
