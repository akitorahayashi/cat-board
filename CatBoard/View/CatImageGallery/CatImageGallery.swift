import ComposableArchitecture
import SwiftUI
import TieredGridLayout

struct CatImageGallery: View {
    @State var store: StoreOf<GalleryReducer>
    
    var body: some View {
        NavigationView {
            ScrollView {
                scrollViewContent
            }
            .navigationTitle("Cat Board")
            .task {
                await store.send(.task).finish()
            }
            .refreshable {
                await store.send(.pullToRefresh).finish()
            }
        }
    }
    
    @ViewBuilder
    private var scrollViewContent: some View {
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
            galleryGrid
            loadMoreSection
        }
    }
    
    @ViewBuilder
    private var galleryGrid: some View {
        TieredGridLayout {
            ForEach(store.items) { image in
                Button {
                    store.send(.imageTapped(image.id))
                } label: {
                    SquareGalleryImageAsync(url: URL(string: image.imageURL))
                        .border(Color(.secondarySystemBackground).opacity(0.6), width: 2)
                        .clipped()
                    
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 2)
            }
            
        }
    }
    
    @ViewBuilder
    private var loadMoreSection: some View {
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

#Preview {
    CatImageGallery(
        store: Store(initialState: GalleryReducer.State()) {
            GalleryReducer()
        }
    )
}
