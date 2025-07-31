import CatAPIClient
import CatImageLoader
import CatImagePrefetcher
import CatImageScreener
import CatImageURLRepository
import SwiftData
import SwiftUI
import TieredGridLayout

struct CatImageGallery: View {
    private static let minImageCountForRefresh = 30

    @StateObject private var viewModel: GalleryViewModel

    init(
        repository: CatImageURLRepositoryProtocol,
        imageLoader: CatImageLoaderProtocol,
        screener: CatImageScreenerProtocol,
        prefetcher: CatImagePrefetcherProtocol
    ) {
        _viewModel = StateObject(wrappedValue: GalleryViewModel(
            repository: repository,
            imageLoader: imageLoader,
            screener: screener,
            prefetcher: prefetcher
        ))
    }

    var body: some View {
        NavigationView {
            Group {
                if viewModel.errorMessage != nil || (!viewModel.isInitializing && viewModel.imageURLsToShow.isEmpty) {
                    errorContent
                        .transition(.opacity)
                } else {
                    ZStack(alignment: .top) {
                        scrollContent
                            .transition(.opacity)

                        // 初期ロード時の ProgressView
                        if viewModel.isInitializing, viewModel.imageURLsToShow.isEmpty {
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
                            .transition(.opacity)
                        }
                    }
                }
            }
            .animation(.easeOut(duration: 0.3), value: viewModel.errorMessage)
            .navigationTitle("Cat Board")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(
                        action: {
                            withAnimation {
                                viewModel.clearDisplayedImages()
                                viewModel.loadInitialImages()
                            }
                        },
                        label: {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundColor(.primary)
                        }
                    )
                    .padding(.leading, 3.6)
                    .accessibilityIdentifier("refreshButton")
                    .opacity(
                        !viewModel.isInitializing && !viewModel.isAdditionalFetching && viewModel.imageURLsToShow
                            .count >= Self.minImageCountForRefresh ? 1 : 0
                    )
                    .animation(.easeOut(duration: 0.3), value: viewModel.isInitializing)
                    .animation(.easeOut(duration: 0.3), value: viewModel.isAdditionalFetching)
                    .animation(.easeOut(duration: 0.3), value: viewModel.imageURLsToShow.count)
                }
            }
            .onAppear {
                viewModel.loadInitialImages()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private var errorContent: some View {
        VStack(spacing: 16) {
            Text("エラーが発生しました")
                .font(.headline)
                .accessibilityIdentifier("errorTitle")
            Text(viewModel.errorMessage ?? "")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: {
                withAnimation {
                    viewModel.clearDisplayedImages()
                    viewModel.loadInitialImages()
                }
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            .accessibilityIdentifier("retryButton")
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var scrollContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            galleryGrid

            // ProgressView
            if viewModel.isAdditionalFetching || viewModel.isInitializing,
               !viewModel.imageURLsToShow.isEmpty
            {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .padding(.bottom, 16)
            }
        }
        .rotationEffect(.degrees(180))
        // 上スクロールできるようにするために回転
        // galleryGrid の中身の要素も回転させている
    }

    @ViewBuilder
    var galleryGrid: some View {
        LazyVStack(spacing: 0) {
            ForEach(
                Array(viewModel.imageURLsToShow.chunked(into: 10).enumerated()),
                id: \.offset
            ) { chunkIndex, chunk in
                TieredGridLayout {
                    ForEach(Array(chunk.enumerated()), id: \.element.id) { index, image in
                        let globalIndex = chunkIndex * 10 + index
                        SquareGalleryImageAsync(url: URL(string: image.imageURL))
                            .padding(2)
                            .transition(.scale(scale: 0.8).combined(with: .opacity))
                            .rotationEffect(.degrees(180))
                            .accessibilityIdentifier("galleryImage_\(globalIndex)")
                            .onAppear {
                                if image.id == viewModel.imageURLsToShow.last?.id {
                                    Task {
                                        await viewModel.fetchAdditionalImages()
                                    }
                                }
                            }
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
