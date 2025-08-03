import CatAPIClient
import CatImageLoader
import CatImagePrefetcher
import CatImageScreener
import CatImageURLRepository
import SwiftData
import SwiftUI
import TieredGridLayout

struct CatImageGallery: View {
    @StateObject private var viewModel: GalleryViewModel
    @State private var isShowingSettings = false
    @State private var gearRotationAngle: Double = 0
    @State private var refreshRotationAngle: Double = 0 // Moved from RefreshButton

    private let prefetcher: CatImagePrefetcherProtocol

    init(
        repository: CatImageURLRepositoryProtocol,
        imageLoader: CatImageLoaderProtocol,
        screener: CatImageScreenerProtocol,
        prefetcher: CatImagePrefetcherProtocol
    ) {
        self.prefetcher = prefetcher
        _viewModel = StateObject(wrappedValue: GalleryViewModel(
            repository: repository,
            imageLoader: imageLoader,
            screener: screener,
            prefetcher: prefetcher
        ))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.isErrorContentVisible {
                    errorContent
                } else if viewModel.isInitialLoadingIndicatorVisible {
                    initialLoadingIndicator
                } else {
                    scrollContent
                }
            }
            .animation(.easeOut(duration: 0.3), value: viewModel.isErrorContentVisible)
            .animation(.easeOut(duration: 0.3), value: viewModel.isInitialLoadingIndicatorVisible)
            .navigationTitle("Cat Board")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                refreshToolbarItem
                settingsToolbarItem
            }
            .onAppear(perform: viewModel.loadInitialImages)
            .sheet(isPresented: $isShowingSettings) {
                SettingsView(prefetcher: prefetcher)
                    .presentationDetents([.medium])
            }
        }
    }
}

// MARK: - View Components

private extension CatImageGallery {
    var initialLoadingIndicator: some View {
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
    }

    var errorContent: some View {
        ErrorView(viewModel: viewModel)
    }

    var scrollContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            galleryGrid
            if viewModel.isAdditionalFetching {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .padding(.bottom, 16)
            }
        }
        .rotationEffect(.degrees(180))
    }

    var galleryGrid: some View {
        LazyVStack(spacing: 0) {
            let chunks = Array(viewModel.imageURLsToShow.chunked(into: 10).enumerated())
            ForEach(chunks, id: \.offset) { chunkIndex, chunk in
                ImageChunkView(
                    viewModel: viewModel,
                    chunk: chunk,
                    chunkIndex: chunkIndex
                )
            }
        }
        .padding(2)
    }
}

// MARK: - Toolbar Items

private extension CatImageGallery {
    var refreshToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            let isDisabled = viewModel.isInitializing || viewModel.isAdditionalFetching || viewModel.isErrorContentVisible
            Button(
                action: {
                    withAnimation(.easeOut(duration: 0.3)) {
                        refreshRotationAngle += 180
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        viewModel.clearDisplayedImages()
                        viewModel.loadInitialImages()
                    }
                },
                label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundColor(.primary)
                        .opacity(isDisabled ? 0.3 : 1)
                        .animation(.easeOut(duration: 0.3), value: isDisabled)
                }
            )
            .rotationEffect(.degrees(refreshRotationAngle))
            .disabled(isDisabled)
            .padding(.leading, 1.2)
            .accessibilityIdentifier(CBAccessibilityID.Gallery.refreshButton)
        }
    }

    var settingsToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: {
                withAnimation(.easeOut(duration: 0.5)) {
                    gearRotationAngle += 360
                }
                isShowingSettings = true
            }) {
                Image(systemName: "gear")
                    .foregroundColor(.primary)
                    .rotationEffect(.degrees(gearRotationAngle))
            }
            .padding(.leading, 1.2)
            .accessibilityIdentifier(CBAccessibilityID.Gallery.settingsButton)
        }
    }
}

// MARK: - Helper Views

private struct ImageChunkView: View {
    @ObservedObject var viewModel: GalleryViewModel
    let chunk: [CatImageURLModel]
    let chunkIndex: Int

    var body: some View {
        TieredGridLayout(items: Array(chunk.enumerated()), id: \.element.id) { item in
            let globalIndex = chunkIndex * 10 + item.offset
            SquareGalleryImageAsync(url: item.element.imageURL)
                .padding(2)
                .transition(.scale(scale: 0.8).combined(with: .opacity))
                .accessibilityIdentifier(CBAccessibilityID.Gallery.image(id: globalIndex))
                .onAppear {
                    if item.element.id == viewModel.imageURLsToShow.last?.id {
                        Task {
                            await viewModel.fetchAdditionalImages()
                        }
                    }
                }
        }
        .rotationEffect(.degrees(180))
    }
}

private struct ErrorView: View {
    @ObservedObject var viewModel: GalleryViewModel
    @State private var retryRotationAngle: Double = 0
    private let rotationAnimationDuration = 0.3
    private let actionDelay = 0.35

    var body: some View {
        VStack(spacing: 16) {
            Text("エラーが発生しました")
                .font(.headline)
                .accessibilityIdentifier(CBAccessibilityID.ErrorView.title)
            Text(viewModel.errorMessage ?? "")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: {
                withAnimation(.easeOut(duration: rotationAnimationDuration)) {
                    retryRotationAngle += 360
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + actionDelay) {
                    viewModel.clearDisplayedImages()
                    viewModel.loadInitialImages()
                }
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.title2)
                    .foregroundColor(.blue)
                    .rotationEffect(.degrees(retryRotationAngle))
            }
            .accessibilityIdentifier(CBAccessibilityID.ErrorView.retryButton)
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Extensions

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
