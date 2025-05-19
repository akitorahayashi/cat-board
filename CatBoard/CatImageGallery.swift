import Infrastructure
import SwiftUI
import TieredGridLayout

struct CatImageGallery: View {
    @StateObject var viewModel = GalleryViewModel(imageClient: CatAPIClient())
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

    private var headerHeight: CGFloat { 16 + UIFont.preferredFont(forTextStyle: .headline).lineHeight }

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
                                await viewModel.fetchAdditionalImages()
                                isTriggeringFetch = false
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                            }
                        }
                    }
            }
            .frame(height: 0)

            Spacer().frame(height: headerHeight)
                .overlay {
                    if viewModel.isLoading, viewModel.catImages.isEmpty {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .padding()
                    }
                }
        }
        .rotationEffect(.degrees(180))
    }

    private var headerView: some View {
        Text("Cat Board")
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            .padding(.bottom, 16)
            .background(Material.ultraThin)
    }

    @ViewBuilder
    var galleryGrid: some View {
        LazyVStack(spacing: 0) {
            ForEach(viewModel.catImages.chunked(into: 10), id: \.self) { chunk in
                TieredGridLayout {
                    ForEach(chunk, id: \.id) { image in
                        SquareGalleryImageAsync(url: URL(string: image.imageURL))
                            .padding(2)
                            .transition(.scale(scale: 0.8).combined(with: .opacity))
                            .rotationEffect(.degrees(180))
                    }
                }
                .padding(2)
            }
        }
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
