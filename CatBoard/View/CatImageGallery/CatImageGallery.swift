import ComposableArchitecture
import SwiftUI
import TieredGridLayout

struct CatImageGallery: View {
    @State var store: StoreOf<GalleryReducer>
    @State private var isTriggeringFetch = false
    
    var body: some View {
        WithPerceptionTracking {
            NavigationView {
                Group {
                    ZStack(alignment: .top) {
                        scrollContent
                        headerView
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
    
    private var headerHeight: CGFloat { 8 + 16 + UIFont.preferredFont(forTextStyle: .headline).lineHeight }

    private var scrollContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                if let errorMessage = store.errorMessage {
                    Text("エラーが発生しました： \(errorMessage)")
                        .rotationEffect(.degrees(180))
                        .padding()
                } else {
                    galleryGrid
                }
            }
            
            
            GeometryReader { geo in
                Color.clear
                    .frame(height: 0)
                    .onChange(of: geo.frame(in: .global).minY) { newY in
                        if newY > 50 && !isTriggeringFetch {
                            isTriggeringFetch = true
                            Task {
                                await store.send(.fetchAdditionalImages).finish()
                                isTriggeringFetch = false
                            }
                        }
                    }
            }
            .frame(height: 0)
            
            if store.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            }
            
            Spacer().frame(height: 24)
            
            Spacer().frame(height: headerHeight)
            
        }
        .rotationEffect(.degrees(180))
    }
    
    private var headerView: some View {
        Text("Cat Board")
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            .padding(.bottom, 16)
            .background(.ultraThinMaterial)
    }
    
    @ViewBuilder
    private func LoadingIndicatorView() -> some View {
        if store.isLoading {
            ProgressView()
                .transition(.scale(scale: 0.8))
                .progressViewStyle(CircularProgressViewStyle())
                .padding(.top, 48)
        }
    }
    
    @ViewBuilder
    private var galleryGrid: some View {
        TieredGridLayout {
            ForEach(store.catImages) { image in
                SquareGalleryImageAsync(url: URL(string: image.imageURL))
                    .padding(2)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                    .animation(.easeOut(duration: 0.3), value: store.catImages)
                    .rotationEffect(.degrees(180))
            }
        }
        .padding(2)
        .animation(.default, value: store.catImages)
    }
}
