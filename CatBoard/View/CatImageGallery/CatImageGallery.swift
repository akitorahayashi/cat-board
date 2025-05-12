import ComposableArchitecture
import SwiftUI
import TieredGridLayout

struct CatImageGallery: View {
    @State var store: StoreOf<GalleryReducer>
    
    var body: some View {
        WithPerceptionTracking {
            NavigationView {
                Group {
                    ZStack(alignment: .top) {
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 0) {
                                if let errorMessage = store.errorMessage {
                                    Text("エラーが発生しました： \(errorMessage)")
                                        .rotationEffect(.degrees(180))
                                        .padding()
                                } else {
                                    galleryGrid
                                }
                                Spacer().frame(height: 46)
                            }
                        }
                        .rotationEffect(.degrees(180))

                        Text("Cat Board")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 8)
                            .padding(.bottom, 16)
                            .background(.ultraThinMaterial)
                    }
                }
                .navigationBarHidden(true)
                .task {
                    await store.send(.onAppear).finish()
                }
            }
            .navigationViewStyle(StackNavigationViewStyle())
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
