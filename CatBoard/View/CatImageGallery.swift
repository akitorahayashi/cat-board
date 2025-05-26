import CBModel
import CatAPIClient
import CatImageURLRepository
import SwiftData
import SwiftUI
import TieredGridLayout
import CatImageScreener
import CatImageLoader
import Kingfisher

struct CatImageGallery: View {
    private static let minImageCountForRefresh = 30
    
    private let modelContainer: ModelContainer
    @StateObject private var viewModel: GalleryViewModel

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        let repository = CatImageURLRepository(modelContainer: modelContainer)
        let loader = CatImageLoader(modelContainer: modelContainer)
        _viewModel = StateObject(wrappedValue: GalleryViewModel(
            repository: repository,
            loader: loader
        ))
    }

    @State private var isTriggeringFetch = false
    @State private var lastTriggerY: CGFloat = 0

    var body: some View {
        NavigationView {
            Group {
                ZStack(alignment: .top) {
                    scrollContent
                    
                    // 初期ロード時のローディング Indicator
                    if viewModel.isLoading, viewModel.imageURLsToShow.isEmpty {
                        VStack {
                            Spacer()
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(1.5)
                            Text("Loading...")
                                .font(.headline)
                                .padding(.top, 8)
                            Spacer()
                        }
                        .transition(.opacity.combined(with: .scale))
                    }
                }
            }
            .navigationTitle("Cat Board")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !viewModel.isLoading && viewModel.imageURLsToShow.count >= Self.minImageCountForRefresh {
                        Button(action: {
                            withAnimation {
                                viewModel.clearDisplayedImages()
                            }
                        }) {
                            ZStack {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }
            }
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
                    .onChange(of: geo.frame(in: .global).minY) { _, newY in
                        guard abs(newY - lastTriggerY) > 50 else { return }
                        guard newY > 50, !isTriggeringFetch, !viewModel.isLoading, !viewModel.imageURLsToShow.isEmpty else { return }

                        isTriggeringFetch = true
                        lastTriggerY = newY

                        Task {
                            await viewModel.fetchAdditionalImages()
                            await MainActor.run {
                                isTriggeringFetch = false
                            }
                        }
                    }
            }
            .frame(height: 0)

            Spacer().frame(height: headerHeight)
                .overlay {
                    if viewModel.isLoading, !viewModel.imageURLsToShow.isEmpty {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .padding()
                    }
                }
        }
        .rotationEffect(.degrees(180))
    }

    @ViewBuilder
    var galleryGrid: some View {
        LazyVStack(spacing: 0) {
            ForEach(viewModel.imageURLsToShow.chunked(into: 10), id: \.self) { chunk in
                TieredGridLayout {
                    ForEach(chunk, id: \.id) { image in
                        SquareGalleryImageAsync(url: URL(string: image.imageURL))
                            .padding(2)
                            .transition(.scale(scale: 0.8).combined(with: .opacity))
                            .rotationEffect(.degrees(180))
                    }
                }
            }
        }
        .padding(2)
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
