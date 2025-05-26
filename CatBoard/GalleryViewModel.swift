import CBModel
import CatAPIClient
import CatImageURLRepository
import CatImageLoader
import CatImageScreener
import Kingfisher
import ScaryCatScreeningKit
import SwiftUI
import SwiftData

@MainActor
final class GalleryViewModel: ObservableObject {
    @Published var imageURLsToShow: [CatImageURLModel] = []
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false

    private let repository: CatImageURLRepositoryProtocol
    private let loader: CatImageLoaderProtocol

    // 画像取得関連
    private static let maxImageCount = 300
    private static let targetInitialDisplayCount = 20
    private static let batchDisplayCount = 10

    // MARK: - Initialization

    init(
        repository: CatImageURLRepositoryProtocol,
        loader: CatImageLoaderProtocol
    ) {
        self.repository = repository
        self.loader = loader
    }

    func loadInitialImages() {
        if imageURLsToShow.isEmpty {
            print("初期画像の読み込み開始: 現在0枚 → 目標\(Self.targetInitialDisplayCount)枚")
            isLoading = true
            Task {
                do {
                    let initialImages = try await loader.fetchImages(count: Self.targetInitialDisplayCount)
                    self.imageURLsToShow = initialImages
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
        print("fetchAdditionalImages開始: 現在\(imageURLsToShow.count)枚表示中")
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
            let prefetchedCount = await loader.getPrefetchedCount()
            if prefetchedCount > 0 {
                let batchCount = min(Self.batchDisplayCount, prefetchedCount)
                let batch = await loader.getPrefetchedImages(count: batchCount)
                imageURLsToShow += batch
                print("画像表示完了: プリフェッチから\(batchCount)枚追加 → 現在\(imageURLsToShow.count)枚表示中(残り\(prefetchedCount - batchCount)枚)")
            } else {
                print("プリフェッチがないため直接取得を開始")
                let newImages = try await loader.fetchImages(count: Self.batchDisplayCount)
                imageURLsToShow += newImages
                print("画像直接取得完了: \(newImages.count)枚追加 → 現在\(imageURLsToShow.count)枚表示中")
            }
            await loader.startPrefetchingIfNeeded()
        } catch let error as NSError {
            errorMessage = error.localizedDescription
            print("画像取得中にエラーが発生: \(error.localizedDescription)")
        }

        isLoading = false
        print("fetchAdditionalImages完了: 現在\(imageURLsToShow.count)枚表示中")
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
