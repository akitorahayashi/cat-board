import CatAPIClient
import CatImageLoader
import CatImageScreener
import CatImageURLRepository
import CBModel
import Kingfisher
import ScaryCatScreeningKit
import SwiftData
import SwiftUI

@MainActor
final class GalleryViewModel: ObservableObject {
    @Published var imageURLsToShow: [CatImageURLModel] = []
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false

    private let repository: CatImageURLRepositoryProtocol
    private let loader: CatImageLoaderProtocol

    // 画像取得関連
    private static let maxImageCount = 300
    private static let targetInitialDisplayCount = 30
    private static let batchDisplayCount = 10

    // MARK: - Initialization

    init(
        repository: CatImageURLRepositoryProtocol,
        loader: CatImageLoaderProtocol
    ) {
        self.repository = repository
        self.loader = loader
    }

    private func fetchImages(imageCount: Int) async throws -> [CatImageURLModel] {
        let prefetchedCount = await loader.getPrefetchedCount()
        if prefetchedCount >= imageCount {
            let images = await loader.getPrefetchedImages(imageCount: imageCount)
            print(
                "画像表示完了: プリフェッチから\(images.count)枚追加 → 現在\(imageURLsToShow.count)枚表示中(残り\(prefetchedCount - images.count)枚)"
            )
            return images
        } else {
            print("プリフェッチが不足しているため直接取得を開始: \(imageCount)枚)")
            let images = try await loader.loadImagesWithScreening(count: imageCount)
            print("画像直接取得完了: \(images.count)枚追加 → 現在\(imageURLsToShow.count)枚表示中")
            return images
        }
    }

    func loadInitialImages() {
        if imageURLsToShow.isEmpty {
            print("初期画像の読み込み開始: 現在0枚 → 目標\(Self.targetInitialDisplayCount)枚")
            isLoading = true
            Task {
                do {
                    self.imageURLsToShow = try await fetchImages(imageCount: Self.targetInitialDisplayCount)
                    self.isLoading = false
                    await loader.startPrefetchingIfNeeded()
                } catch let error as NSError {
                    self.errorMessage = error.localizedDescription
                    self.imageURLsToShow = []
                    self.isLoading = false
                }
            }
        }
    }

    func fetchAdditionalImages() async {
        if imageURLsToShow.count > Self.maxImageCount {
            print("最大表示枚数(\(Self.maxImageCount)枚)に到達したため、画像をクリアして再読み込みします")
            clearDisplayedImages()
            return
        }
        guard !isLoading else {
            print("既にローディング中のため、スキップします")
            return
        }
        isLoading = true
        errorMessage = nil

        do {
            let newImages = try await fetchImages(imageCount: Self.batchDisplayCount)
            imageURLsToShow += newImages
            await loader.startPrefetchingIfNeeded()
        } catch let error as NSError {
            errorMessage = error.localizedDescription
            print("画像取得中にエラーが発生: \(error.localizedDescription)")
        }

        isLoading = false
    }

    func clearDisplayedImages() {
        print("画像のクリアを開始")
        // 全ての画像をクリア
        imageURLsToShow = []
        errorMessage = nil

        // Kingfisherのメモリキャッシュをクリア
        KingfisherManager.shared.cache.clearMemoryCache()

        // 初期化処理を実行
        loadInitialImages()
    }
}
