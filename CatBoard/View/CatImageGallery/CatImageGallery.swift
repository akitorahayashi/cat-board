import ComposableArchitecture
import SwiftUI
import TieredGridLayout

struct CatImageGallery: View {
    @State var store: StoreOf<GalleryReducer>

    var body: some View {
        WithPerceptionTracking {
            NavigationView {
                Group {
                    if store.imageRepository.isLoading, store.imageRepository.items.isEmpty {
                        ProgressView("Loading...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(.systemBackground).edgesIgnoringSafeArea(.all))
                    } else {
                        ScrollView {
                            VStack {
                                if let errorMessage = store.imageRepository.errorMessage {
                                    Text("Error: \(errorMessage)")
                                        .foregroundColor(.red)
                                        .padding()
                                } else if store.imageRepository.items.isEmpty, !store.imageRepository.isLoading {
                                    Text("サーバーエラーが発生しました。")
                                        .padding()
                                } else {
                                    galleryGrid
                                    loadMoreSection
                                }
                            }
                            .animation(.default, value: store.imageRepository.isLoadingMore)
                            .animation(.default, value: store.imageRepository.canLoadMore)
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
                .transition(.opacity)
            }
        }
        .animation(.default, value: store.imageRepository.items)
    }

    @ViewBuilder
    private var loadMoreSection: some View {
        if store.imageRepository.initialLoadCompleted {
            if store.imageRepository.isLoadingMore {
                ProgressView()
                    .padding()
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
            } else if store.imageRepository.canLoadMore {
                Button("Load More") {
                    store.send(.imageRepository(.loadMoreImages))
                }
                .padding()
                .transition(.opacity)
            }
        }
    }
}
