import ScaryCatScreeningKit
import Kingfisher
import CBShared
import Infrastructure
import SwiftUI

class GalleryViewModel: ObservableObject {
    @Published var imageURLsToShow: [CatImageURLModel] = []
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false
    
    private let repository: CatImageURLRepository
    private let imageClient: CatAPIClient
    private static let imagesPerFetch = 10
    private static let maxImageCount = 300
    
    private static let targetInitialDisplayCount = 20
    private static let targetPrefetchCount = 50
    private static let minPrefetchThreshold = 20
    private static let batchDisplayCount = 10
    
    private var prefetchedImages: [CatImageURLModel] = []
    private var screener: ScaryCatScreener?

    init(repository: CatImageURLRepository, imageClient: CatAPIClient) {
        self.repository = repository
        self.imageClient = imageClient
        // KingfisherManagerのキャッシュの保存期間を設定
        KingfisherManager.shared.cache.diskStorage.config.sizeLimit = 500 * 1024 * 1024 // 500MB
        KingfisherManager.shared.cache.diskStorage.config.expiration = .days(3)
    }
    
    
    @MainActor func onAppear() {
        if imageURLsToShow.isEmpty {
            print("初期画像の読み込み開始: 現在0枚 → 目標\(Self.targetInitialDisplayCount)枚")
            Task {
                if screener == nil {
                    do {
                        screener = try await ScaryCatScreener()
                    } catch {
                        print("ScaryCatScreenerの初期化に失敗")
                        return
                    }
                }
                var loadedModels: [CatImageURLModel] = []
                var loadedImages: [UIImage] = []
                let loaded = try? await repository.provideImageURLs(imagesCount: Self.targetInitialDisplayCount, using: imageClient)
                for urlModel in loaded ?? [] {
                    guard let url = URL(string: urlModel.imageURL) else { continue }
                    do {
                        let result = try await KingfisherManager.shared.downloader.downloadImage(with: url)
                        let image = result.image
                        loadedModels.append(urlModel)
                        loadedImages.append(image)
                        if loadedModels.count >= Self.targetInitialDisplayCount {
                            break
                        }
                    } catch {
                        continue
                    }
                }
                do {
                    let screenedImages = try await screener!.screen(
                        images: loadedImages,
                        probabilityThreshold: 0.85,
                        enableLogging: false
                    )
                    var filteredModels: [CatImageURLModel] = []
                    for screenedImage in screenedImages {
                        if let index = loadedImages.firstIndex(of: screenedImage) {
                            filteredModels.append(loadedModels[index])
                        }
                    }
                    print("初期画像の読み込み完了: \(loadedModels.count)枚読み込み → \(filteredModels.count)枚表示")
                    self.imageURLsToShow = Array(filteredModels.prefix(Self.targetInitialDisplayCount))
                } catch {
                    print("スクリーニングに失敗: \(error.localizedDescription)")
                    self.errorMessage = error.localizedDescription
                    self.imageURLsToShow = []
                }
                
                await startBackgroundPrefetchingIfNeeded()
            }
        }
    }
    
    @MainActor
    func fetchAdditionalImages() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        
        let batchCount = min(Self.batchDisplayCount, prefetchedImages.count)
        if batchCount > 0 {
            let batch = prefetchedImages.prefix(batchCount)
            imageURLsToShow += batch
            prefetchedImages.removeFirst(batchCount)
            print("追加画像の表示完了: プリフェッチから\(batchCount)枚追加 → 現在\(imageURLsToShow.count)枚表示中")
        }
        
        if imageURLsToShow.count > Self.maxImageCount {
            print("キャッシュクリア実行: 表示数\(imageURLsToShow.count)枚が上限\(Self.maxImageCount)枚を超過 → リセット")
            imageURLsToShow = []
            KingfisherManager.shared.cache.clearMemoryCache()
            Task.detached {
                await KingfisherManager.shared.cache.clearDiskCache()
            }
        }
        
        if prefetchedImages.count <= Self.minPrefetchThreshold {
            await startBackgroundPrefetchingIfNeeded()
        }
        
        isLoading = false
    }
    
    private func prefetchImage(_ model: CatImageURLModel) {
        if let url = URL(string: model.imageURL) {
            let resource = KF.ImageResource(downloadURL: url)
            ImagePrefetcher(resources: [resource]).start()
            prefetchedImages.append(model)
        }
    }
    
    @MainActor
    func startBackgroundPrefetchingIfNeeded() async {
        guard prefetchedImages.count < Self.targetPrefetchCount else { return }
        print("プリフェッチ開始: 現在\(prefetchedImages.count)枚 → 目標\(Self.targetPrefetchCount)枚")
        if screener == nil {
            do {
                screener = try await ScaryCatScreener()
            } catch {
                print("ScaryCatScreenerの初期化に失敗")
                return
            }
        }
        do {
            let countToFetch = Self.targetPrefetchCount - prefetchedImages.count
            let newImages = try await repository.provideImageURLs(imagesCount: countToFetch, using: imageClient)
            var loadedModels: [CatImageURLModel] = []
            var loadedUIImages: [UIImage] = []
            for item in newImages {
                guard let url = URL(string: item.imageURL) else { continue }
                do {
                    let result = try await KingfisherManager.shared.downloader.downloadImage(with: url)
                    let image = result.image
                    loadedModels.append(item)
                    loadedUIImages.append(image)
                } catch {
                    continue
                }
            }
            let screened = try await screener!.screen(images: loadedUIImages, probabilityThreshold: 0.99, enableLogging: false)
            for screenedImage in screened {
                if let index = loadedUIImages.firstIndex(of: screenedImage) {
                    prefetchImage(loadedModels[index])
                }
            }
            print("プリフェッチ完了: \(loadedUIImages.count)枚読み込み → \(screened.count)枚追加済")
        } catch {
            print("プリフェッチに失敗: \(error.localizedDescription)")
            self.errorMessage = error.localizedDescription
        }
    }
}
