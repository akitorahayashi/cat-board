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
                await store.send(.imageRepository(.pullToRefresh)).finish()
            }
        }
    }

    @ViewBuilder
    private var scrollViewContent: some View {
        if store.imageRepository.isLoading {
            ProgressView("Loading...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
        } else if let errorMessage = store.imageRepository.errorMessage {
            Text("Error: \(errorMessage)")
                .foregroundColor(.red)
                .padding()
        } else if store.imageRepository.items.isEmpty {
            Text("サーバーエラーが発生しました。")
                .padding()
        } else {
            galleryGrid
            loadMoreSection
        }
    }

    @ViewBuilder
    private var galleryGrid: some View {
        WithPerceptionTracking {
            TieredGridLayout {
                ForEach(store.imageRepository.items) { image in
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
    }

    @ViewBuilder
    private var loadMoreSection: some View {
        if store.imageRepository.canLoadMore, !store.imageRepository.isLoadingMore {
            Button("Load More") {
                store.send(.imageRepository(.fetchImages))
            }
            .padding()
        } else if store.imageRepository.isLoadingMore {
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
