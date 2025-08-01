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
    @State private var isShowingSettings = false
    @State private var gearRotationAngle: Double = 0
    @State private var refreshRotationAngle: Double = 0
    @State private var retryRotationAngle: Double = 0

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

    private var isErrorContentVisible: Bool {
        viewModel.errorMessage != nil || (!viewModel.isInitializing && viewModel.imageURLsToShow.isEmpty)
    }

    private var isInitialLoadingIndicatorVisible: Bool {
        viewModel.isInitializing && viewModel.imageURLsToShow.isEmpty
    }

    var body: some View {
        NavigationView {
            ZStack {
                errorContent
                    .opacity(isErrorContentVisible ? 1 : 0)
                    .allowsHitTesting(isErrorContentVisible)
                    .animation(.easeOut(duration: 0.3), value: viewModel.errorMessage)

                ZStack(alignment: .top) {
                    scrollContent
                        .opacity(isErrorContentVisible ? 0 : 1)
                        .allowsHitTesting(!isErrorContentVisible)
                        .animation(.easeOut(duration: 0.3), value: viewModel.errorMessage)

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
                    .opacity(isInitialLoadingIndicatorVisible ? 1 : 0)
                    .animation(.easeOut(duration: 0.3), value: isInitialLoadingIndicatorVisible)
                }
            }
            .navigationTitle("Cat Board")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                refreshToolbarItem
                settingsToolbarItem
            }
            .onAppear {
                viewModel.loadInitialImages()
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView(prefetcher: prefetcher)
                    .presentationDetents([.medium])
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private var refreshToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            let isDisabled = viewModel.isInitializing || viewModel.isAdditionalFetching || isErrorContentVisible
            Button(
                action: {
                    withAnimation(.easeOut(duration: 0.3)) {
                        refreshRotationAngle += 180
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
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
            .accessibilityIdentifier("refreshButton")
        }
    }

    private var settingsToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(
                action: {
                    withAnimation(.easeOut(duration: 0.5)) {
                        gearRotationAngle += 360
                    }
                    isShowingSettings = true
                },
                label: {
                    Image(systemName: "gear")
                        .foregroundColor(.primary)
                        .rotationEffect(.degrees(gearRotationAngle))
                }
            )
            .padding(.leading, 1.2)
            .accessibilityIdentifier("settingsButton")
        }
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
                withAnimation(.easeOut(duration: 0.3)) {
                    retryRotationAngle += 360
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    viewModel.clearDisplayedImages()
                    viewModel.loadInitialImages()
                }
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.title2)
                    .foregroundColor(.blue)
                    .rotationEffect(.degrees(retryRotationAngle))
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
