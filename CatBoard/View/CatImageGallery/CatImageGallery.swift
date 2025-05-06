import ComposableArchitecture
import SwiftUI
import TieredGridLayout

struct CatImageGallery: View {
    @State var store: StoreOf<GalleryReducer>

    var body: some View {
        WithPerceptionTracking {
            NavigationView {
                Group {
                    if store.imageRepository.isLoading && store.imageRepository.items.isEmpty {
                        ProgressView("Loading...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(.systemBackground).edgesIgnoringSafeArea(.all))
                    } else {
                        ScrollView {
                            if let errorMessage = store.imageRepository.errorMessage {
                                Text("Error: \(errorMessage)")
                                    .foregroundColor(.red)
                                    .padding()
                            } else if store.imageRepository.items.isEmpty && !store.imageRepository.isLoading {
                                Text("サーバーエラーが発生しました。")
                                    .padding()
                            } else {
                                galleryGrid
                                loadMoreSection
                            }
                        }
                        .refreshable {
                            await store.send(.imageRepository(.pullRefresh)).finish()
                        }
                    }
                }
                .navigationTitle("Cat Board")
                .task {
                    await store.send(.loadInitialImages).finish()
                }
            }
        }
    }

    @ViewBuilder
    private var galleryGrid: some View {
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

    @ViewBuilder
    private var loadMoreSection: some View {
        if store.imageRepository.canLoadMore, !store.imageRepository.isLoadingMore {
            Button("Load More") {
                store.send(.imageRepository(.loadMoreImages))
            }
            .padding()
        }
    }
}
