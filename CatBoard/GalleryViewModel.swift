import CBModel
import CatAPIClient
import CatImageURLRepository
import CatImagePrefetcher
import CatImageScreener
import Kingfisher
import ScaryCatScreeningKit
import SwiftUI

class GalleryViewModel: ObservableObject {
    @Published var imageURLsToShow: [CatImageURLModel] = []
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false

    private let repository: CatImageURLRepository
    private let imageClient: CatAPIClient
    private let prefetcher: CatImagePrefetcher
    private let screener: CatImageScreener

    // 画像取得関連
    private static let maxImageCount = 300
    private static let targetInitialDisplayCount = 20
    private static let batchDisplayCount = 10

    // スクリーニング関連
    private static let isScreeningEnabled = true
    private static let screeningProbabilityThreshold: Float = 0.85
    private static let scaryMode = false  // 怖い画像のみを表示するモード
    private var isPrefetching: Bool = false
    private var prefetchTask: Task<Void, Never>?

    // キャッシュの保存期間関係の定数
    private static let kingfisherCacheSizeLimit: UInt = 500 * 1024 * 1024 // 500MB
    private static let kingfisherCacheExpirationDays = 1

    private var prefetchedImages: [CatImageURLModel] = []
    private static let prefetchBatchCount = 10 // 一回のプリフェッチでロードして screener に通す枚数
    private static let minPrefetchThreshold = 180 // プリフェッチを開始する閾値
    private static let targetPrefetchCount = 200 // プリフェッチの目標枚数

    // MARK: - Initialization

    init(repository: CatImageURLRepository, imageClient: CatAPIClient) {
        self.repository = repository
        self.imageClient = imageClient
        self.prefetcher = CatImagePrefetcher(repository: repository, imageClient: imageClient)
        self.screener = CatImageScreener()
    }

    deinit {
        prefetchTask?.cancel()
        KingfisherManager.shared.cache.clearMemoryCache()
    }

    @MainActor func onAppear() {
        if imageURLsToShow.isEmpty {
            print("初期画像の読み込み開始: 現在0枚 → 目標\(Self.targetInitialDisplayCount)枚")
            isLoading = true
            Task {
                do {
                    let initialImages = try await prefetcher.fetchImages(count: Self.targetInitialDisplayCount)
                    await MainActor.run {
                        self.imageURLsToShow = initialImages
                        self.isLoading = false
                    }
                    startCatImagePrefetchingIfNeeded()
                } catch let error as NSError {
                    await MainActor.run {
                        self.errorMessage = error.localizedDescription
                        self.imageURLsToShow = []
                        self.isLoading = false
                    }
                }
            }
        }
    }

    @MainActor
    func fetchAdditionalImages() async {
        print("fetchAdditionalImages開始: 現在\(imageURLsToShow.count)枚表示中")
        // 追加取得前にmaxImageCountを超えていたらクリアして再読み込み
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
            let prefetchedCount = await prefetcher.getPrefetchedCount()
            if prefetchedCount > 0 {
                let batchCount = min(Self.batchDisplayCount, prefetchedCount)
                let batch = await prefetcher.getPrefetchedImages(count: batchCount)
                imageURLsToShow += batch
                print("画像表示完了: プリフェッチから\(batchCount)枚追加 → 現在\(imageURLsToShow.count)枚表示中(残り\(prefetchedCount - batchCount)枚)")

                if prefetchedCount - batchCount <= 180 {
                    startCatImagePrefetchingIfNeeded()
                }
            } else {
                print("プリフェッチがないため直接取得を開始")
                let newImages = try await prefetcher.fetchImages(count: Self.batchDisplayCount)
                imageURLsToShow += newImages
                print("画像直接取得完了: \(newImages.count)枚追加 → 現在\(imageURLsToShow.count)枚表示中")
            }
        } catch let error as NSError {
            errorMessage = error.localizedDescription
            print("画像取得中にエラーが発生: \(error.localizedDescription)")
        }

        isLoading = false
        print("fetchAdditionalImages完了: 現在\(imageURLsToShow.count)枚表示中")
    }

    @MainActor
    func startCatImagePrefetchingIfNeeded() {
        Task {
            await prefetcher.startPrefetchingIfNeeded()
        }
    }

    @MainActor
    func clearDisplayedImages() {
        print("画像のクリアを開始")
        // 表示中の画像をクリア
        imageURLsToShow = []
        
        // メモリキャッシュのクリア
        KingfisherManager.shared.cache.clearMemoryCache()
        
        // エラーメッセージのクリア
        errorMessage = nil
        
        // 画像の再読み込みを開始
        print("画像の再読み込みを開始")
        Task {
            await fetchAdditionalImages()
        }
    }
}
