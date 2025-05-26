import CatAPIClient
import CatImageLoader
import CatImageScreener
import CatImageURLRepository
import CBModel
import Kingfisher
import SwiftData
import SwiftUI
import TieredGridLayout
import UIKit

struct CatImageGallery: View {
    private static let minImageCountForRefresh = 30

    private let modelContainer: ModelContainer
    @StateObject private var viewModel: GalleryViewModel

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        let imageClient = CatAPIClient()
        let repository = CatImageURLRepository(modelContainer: modelContainer, apiClient: imageClient)
        let screener = CatImageScreener()
        let loader = CatImageLoader(
            modelContainer: modelContainer,
            repository: repository,
            screener: screener,
            imageClient: imageClient
        )
        _viewModel = StateObject(wrappedValue: GalleryViewModel(
            repository: repository,
            loader: loader
        ))
    }

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
                    if !viewModel.isLoading, viewModel.imageURLsToShow.count >= Self.minImageCountForRefresh {
                        Button(
                            action: {
                                withAnimation {
                                    viewModel.clearDisplayedImages()
                                }
                            },
                            label: {
                                ZStack {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .foregroundColor(.primary)
                                }
                            }
                        )
                    }
                }
            }
            .onAppear {
                viewModel.loadInitialImages()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private var scrollContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                Color.clear
                    .frame(height: 0)

                if let errorMessage = viewModel.errorMessage {
                    Text("エラーが発生しました： \(errorMessage)")
                        .rotationEffect(.degrees(180))
                        .padding()
                } else {
                    galleryGrid
                }
            }

            if viewModel.isLoading, !viewModel.imageURLsToShow.isEmpty {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .padding(.bottom, 20)
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
