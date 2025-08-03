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
    @State private var refreshRotationAngle: Double = 0
    @State private var retryRotationAngle: Double = 0

    private let prefetcher: CatImagePrefetcherProtocol

    private let animationDuration: Double = 0.3
    private let actionDelay: Double = 0.35

    private var isErrorContentVisible: Bool {
        viewModel.errorMessage != nil || (!viewModel.isInitializing && viewModel.imageURLsToShow.isEmpty)
    }

    private var isInitialLoadingIndicatorVisible: Bool {
        viewModel.isInitializing && viewModel.imageURLsToShow.isEmpty
    }

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
                if isErrorContentVisible {
                    errorContent
                } else if isInitialLoadingIndicatorVisible {
                    initialLoadingIndicator
                } else {
                    scrollContent
                }
            }
            .animation(.easeOut(duration: animationDuration), value: isErrorContentVisible)
            .animation(.easeOut(duration: animationDuration), value: isInitialLoadingIndicatorVisible)
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

    @ViewBuilder
    var errorContent: some View {
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
                withAnimation(.easeOut(duration: animationDuration)) {
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

    @ViewBuilder
    var galleryGrid: some View {
        LazyVStack(spacing: 0) {
            let chunks = Array(viewModel.imageURLsToShow.chunked(into: 10).enumerated())
            ForEach(chunks, id: \.offset) { chunkIndex, chunk in
                TieredGridLayout {
                    ForEach(Array(chunk.enumerated()), id: \.element.id) { index, image in
                        let globalIndex = chunkIndex * 10 + index
                        SquareGalleryImageAsync(url: image.imageURL)
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

// MARK: - Toolbar Items

private extension CatImageGallery {
    var refreshToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            let isDisabled = viewModel.isInitializing || viewModel.isAdditionalFetching || isErrorContentVisible
            Button(
                action: {
                    withAnimation(.easeOut(duration: animationDuration)) {
                        refreshRotationAngle += 180
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + actionDelay) {
                        viewModel.clearDisplayedImages()
                        viewModel.loadInitialImages()
                    }
                },
                label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundColor(.primary)
                        .opacity(isDisabled ? 0.3 : 1)
                        .animation(.easeOut(duration: animationDuration), value: isDisabled)
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
                withAnimation(.easeOut(duration: animationDuration)) {
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

// MARK: - Extensions

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
