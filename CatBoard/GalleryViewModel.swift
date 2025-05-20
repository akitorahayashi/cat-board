import CBShared
import Infrastructure
import Kingfisher
import ScaryCatScreeningKit
import SwiftUI

class GalleryViewModel: ObservableObject {
    @Published var imageURLsToShow: [CatImageURLModel] = []
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false

    private let repository: CatImageURLRepository
    private let imageClient: CatAPIClient

    // 画像取得関連の定数
    private static let imagesPerFetch = 10
    private static let maxImageCount = 300
    private static let targetInitialDisplayCount = 30
    private static let batchDisplayCount = 10

    // スクリーニング関連
    private static let isScreeningEnabled = false
    private static let screeningProbabilityThreshold: Float = 0.85
    private static let prefetchScreeningProbabilityThreshold: Float = 1.00
    private var screener: ScaryCatScreener?
    private var isPrefetching: Bool = false
    private var prefetchTask: Task<Void, Never>?

    // キャッシュの保存期間関係の定数
    private static let kingfisherCacheSizeLimit: UInt = 500 * 1024 * 1024 // 500MB
    private static let kingfisherCacheExpirationDays = 3
    
    private var prefetchedImages: [CatImageURLModel] = []
    private static let prefetchBatchCount = 60  // 一回のプリフェッチで取得する枚数
    private static let minPrefetchThreshold = 50  // プリフェッチを開始する閾値

    // MARK: - Initialization
    init(repository: CatImageURLRepository, imageClient: CatAPIClient) {
        self.repository = repository
        self.imageClient = imageClient
        KingfisherManager.shared.cache.diskStorage.config.sizeLimit = GalleryViewModel.kingfisherCacheSizeLimit
        KingfisherManager.shared.cache.diskStorage.config.expiration = .days(GalleryViewModel.kingfisherCacheExpirationDays)
    }

    deinit {
        prefetchTask?.cancel()
        KingfisherManager.shared.cache.clearMemoryCache()
    }

    @MainActor func onAppear() {
        if imageURLsToShow.isEmpty {
            print("初期画像の読み込み開始: 現在0枚 → 目標\(Self.targetInitialDisplayCount)枚")
            Task {
                do {
                    if screener == nil {
                        screener = try await ScaryCatScreener()
                    }
                    
                    let loaded = try await repository.getNextImageURLsFromCacheOrAPI(
                        count: Self.targetInitialDisplayCount,
                        using: imageClient
                    )
                    
                    var loadedImages: [UIImage] = []
                    var screenedURLs: [CatImageURLModel] = []
                    
                    // 一度に必要な枚数を読み込む
                    for urlModel in loaded.prefix(Self.targetInitialDisplayCount) {
                        guard let url = URL(string: urlModel.imageURL) else { continue }
                        do {
                            let result = try await KingfisherManager.shared.downloader.downloadImage(with: url)
                            loadedImages.append(result.image)
                            screenedURLs.append(urlModel)
                            if loadedImages.count >= Self.targetInitialDisplayCount {
                                break
                            }
                        } catch {
                            continue
                        }
                    }
                    
                    let screenedImages = try await screener?.screen(
                        images: loadedImages,
                        probabilityThreshold: GalleryViewModel.screeningProbabilityThreshold,
                        enableLogging: false
                    ) ?? []
                    
                    // スクリーニング通過した画像のURLのみを保持
                    if Self.isScreeningEnabled {
                        var filteredURLs: [CatImageURLModel] = []
                        for (index, urlModel) in screenedURLs.enumerated() {
                            if index < screenedImages.count {
                                filteredURLs.append(urlModel)
                            }
                        }
                        screenedURLs = filteredURLs
                    }
                    
                    print("初期画像の読み込み完了: \(loadedImages.count)枚読み込み → \(screenedURLs.count)枚表示")
                    
                    // 画像URLの更新を一括で行う
                    await MainActor.run {
                        self.imageURLsToShow = screenedURLs
                    }
                    
                    startBackgroundPrefetchingIfNeeded()
                } catch {
                    await MainActor.run {
                        self.errorMessage = error.localizedDescription
                        self.imageURLsToShow = []
                    }
                }
            }
        }
    }

    @MainActor
    func fetchAdditionalImages() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        do {
            if !prefetchedImages.isEmpty {
                let batchCount = min(Self.batchDisplayCount, prefetchedImages.count)
                let batch = prefetchedImages.prefix(batchCount)
                imageURLsToShow += batch
                prefetchedImages.removeFirst(batchCount)
                print("画像表示完了: プリフェッチから\(batchCount)枚追加 → 現在\(imageURLsToShow.count)枚表示中(残り\(prefetchedImages.count)枚)")

                if prefetchedImages.count <= Self.minPrefetchThreshold {
                    startBackgroundPrefetchingIfNeeded()
                }
            } else {
                print("プリフェッチがないため直接取得を開始")
                let newImages = try await repository.getNextImageURLsFromCacheOrAPI(
                    count: Self.batchDisplayCount,
                    using: imageClient
                )
                
                var loadedImages: [UIImage] = []
                var screenedURLs: [CatImageURLModel] = []
                
                for urlModel in newImages {
                    guard let url = URL(string: urlModel.imageURL) else { continue }
                    do {
                        let result = try await KingfisherManager.shared.downloader.downloadImage(with: url)
                        loadedImages.append(result.image)
                    } catch {
                        continue
                    }
                }

                if screener == nil {
                    screener = try await ScaryCatScreener()
                }

                let screened = try await screener?.screen(
                    images: loadedImages,
                    probabilityThreshold: GalleryViewModel.screeningProbabilityThreshold,
                    enableLogging: false
                ) ?? []

                // スクリーニング通過した画像のURLのみを保持
                if Self.isScreeningEnabled {
                    for (index, urlModel) in newImages.prefix(loadedImages.count).enumerated() {
                        if index < screened.count {
                            screenedURLs.append(urlModel)
                        }
                    }
                } else {
                    screenedURLs = Array(newImages.prefix(loadedImages.count))
                }

                imageURLsToShow += screenedURLs
                print("画像直接取得完了: \(loadedImages.count)枚読み込み → \(Self.isScreeningEnabled ? "スクリーニング通過" : "")\(screenedURLs.count)枚")
            }

            if imageURLsToShow.count > Self.maxImageCount {
                imageURLsToShow = []
                KingfisherManager.shared.cache.clearMemoryCache()
                Task.detached {
                    await KingfisherManager.shared.cache.clearDiskCache()
                }
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    @MainActor
    func startBackgroundPrefetchingIfNeeded() {
        guard !isPrefetching else { return }
        guard prefetchedImages.count < Self.minPrefetchThreshold else { return }
        
        prefetchTask?.cancel()
        
        prefetchTask = Task { [weak self] in
            guard let self = self else { return }
            do {
                self.isPrefetching = true
                print("画像プリフェッチ開始: 現在\(prefetchedImages.count)枚 → 目標\(Self.prefetchBatchCount)枚")
                
                if screener == nil {
                    screener = try await ScaryCatScreener()
                }
                
                let newImages = try await repository.getNextImageURLsFromCacheOrAPI(
                    count: Self.prefetchBatchCount,
                    using: imageClient
                )
                
                var loadedImages: [UIImage] = []
                var loadedModels: [CatImageURLModel] = []
                
                for item in newImages {
                    guard let url = URL(string: item.imageURL) else { continue }
                    do {
                        let result = try await KingfisherManager.shared.downloader.downloadImage(with: url)
                        loadedImages.append(result.image)
                        loadedModels.append(item)
                    } catch {
                        continue
                    }
                }
                
                let screened = try await screener?.screen(
                    images: loadedImages,
                    probabilityThreshold: GalleryViewModel.prefetchScreeningProbabilityThreshold,
                    enableLogging: false
                ) ?? []
                
                var filteredModels: [CatImageURLModel] = []
                if Self.isScreeningEnabled {
                    for (index, model) in loadedModels.enumerated() {
                        if index < screened.count {
                            filteredModels.append(model)
                        }
                    }
                } else {
                    filteredModels = loadedModels
                }
                
                prefetchedImages = filteredModels
                print("画像プリフェッチ完了: \(loadedImages.count)枚読み込み → \(Self.isScreeningEnabled ? "スクリーニング通過" : "")\(filteredModels.count)枚")
            } catch {
                self.errorMessage = error.localizedDescription
            }
            self.isPrefetching = false
        }
    }
}
