import CatImageLoader
import CatImageURLRepository
import CBModel
import Kingfisher
import SwiftUI

@MainActor
final class GalleryViewModel: ObservableObject {
    @Published var imageURLsToShow: [CatImageURLModel] = []
    @Published var errorMessage: String?
    @Published var isInitializing: Bool = false
    @Published var isAdditionalFetching: Bool = false

    private let repository: CatImageURLRepositoryProtocol
    private let loader: CatImageLoaderProtocol

    // 画像取得関連
    static let maxImageCount = 300
    static let targetInitialDisplayCount = 30
    static let batchDisplayCount = 10

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
            let startTime = Date()
            print("初期画像の読み込み開始: 現在0枚 → 目標\(Self.targetInitialDisplayCount)枚")
            isInitializing = true
            print("koko")
            Task {
                do {
                    self.imageURLsToShow = try await fetchImages(imageCount: Self.targetInitialDisplayCount)
                    let endTime = Date()
                    let timeInterval = endTime.timeIntervalSince(startTime)
                    print("初期画像の読み込み完了: \(String(format: "%.2f", timeInterval))秒")
                    self.isInitializing = false
                    await loader.startPrefetchingIfNeeded()
                } catch let error as NSError {
                    print("loadInitialImages でエラーが発生: \(error.localizedDescription)")
                    self.errorMessage = error.localizedDescription
                    self.imageURLsToShow = []
                    self.isInitializing = false
                }
            }
        }
    }

    func fetchAdditionalImages() async {
        guard !isAdditionalFetching && !isInitializing else {
            print("既にローディング中のため、スキップします")
            return
        }
        isAdditionalFetching = true
        errorMessage = nil

        do {
            let newImages = try await fetchImages(imageCount: Self.batchDisplayCount)
            imageURLsToShow += newImages

            // 最大画像数を超えた場合はクリアして再読み込み
            if imageURLsToShow.count > Self.maxImageCount {
                print("最大表示枚数(\(Self.maxImageCount)枚)に到達したため、画像をクリアして再読み込みします")
                clearDisplayedImages()
                loadInitialImages()
                return
            }

            await loader.startPrefetchingIfNeeded()
        } catch let error as NSError {
            print("追加画像読み込みでエラーが発生: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }

        isAdditionalFetching = false
    }

    func clearDisplayedImages() {
        print("画像のクリアを開始")
        
        // 配列を空にする
        imageURLsToShow.removeAll()
        errorMessage = nil

        // Kingfisherのメモリキャッシュをクリア
        KingfisherManager.shared.cache.clearMemoryCache()
        
        // Kingfisherのディスクキャッシュをクリア
        KingfisherManager.shared.cache.clearDiskCache()
    }
}
