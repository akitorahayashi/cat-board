import ComposableArchitecture
import SwiftUI
import TieredGridLayout

struct CatImageGallery: View {
    @State var store: StoreOf<GalleryReducer>

    var body: some View {
        WithPerceptionTracking {
            NavigationView {
                Group {
                    if store.isLoading, store.items.isEmpty {
                        ProgressView("Loading...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(.systemBackground).edgesIgnoringSafeArea(.all))
                    } else {
                        ScrollView {
                            VStack {
                                if let errorMessage = store.errorMessage {
                                    Text("Error: \(errorMessage)")
                                        .foregroundColor(.red)
                                        .padding()
                                } else if store.items.isEmpty, !store.isLoading {
                                    Text("サーバーエラーが発生しました。")
                                        .padding()
                                } else {
                                    galleryGrid
                                }
                            }
                        }
                        .refreshable {
                            await store.send(.pullRefresh).finish()
                        }
                    }
                }
                .navigationTitle("Cat Board")
                .task {
                    await store.send(.onAppear).finish()
                }
            }
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
                .transition(.opacity)
            }
        }
        .animation(.default, value: store.items)
    }
}
