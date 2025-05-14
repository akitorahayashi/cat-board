import Infrastructure
import SwiftUI
import TieredGridLayout

struct CatImageGallery: View {
    @StateObject var viewModel = GalleryViewModel(imageClient: LiveImageClient())
    @State private var isTriggeringFetch = false

    var body: some View {
        NavigationView {
            Group {
                ZStack(alignment: .top) {
                    scrollContent
                    headerView
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                viewModel.onAppear()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private var headerHeight: CGFloat { 8 + 16 + UIFont.preferredFont(forTextStyle: .headline).lineHeight }

    private var scrollContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                if let errorMessage = viewModel.errorMessage {
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
                        if newY > 50, !isTriggeringFetch, !viewModel.isLoading {
                            isTriggeringFetch = true
                            Task {
                                viewModel.fetchAdditionalImages()
                                isTriggeringFetch = false
                            }
                        }
                    }
            }
            .frame(height: 0)

            if viewModel.isLoading, viewModel.catImages.isEmpty {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            } else if viewModel.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .padding()
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
    private var galleryGrid: some View {
        TieredGridLayout {
            ForEach(viewModel.catImages) { image in
                SquareGalleryImageAsync(url: URL(string: image.imageURL))
                    .padding(2)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                    .rotationEffect(.degrees(180))
            }
        }
        .padding(2)
    }
}
