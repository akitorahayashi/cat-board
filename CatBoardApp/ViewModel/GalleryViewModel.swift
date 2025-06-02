import CatImageLoader
import CatImagePrefetcher
import CatImageScreener
import CatImageURLRepository
import CBModel
import Kingfisher
import SwiftUI

final class GalleryViewModel: ObservableObject {
    @Published var imageURLsToShow: [CatImageURLModel] = []
    @Published var errorMessage: String?
    @Published var isInitializing: Bool = false
    @Published var isAdditionalFetching: Bool = false

    private let repository: CatImageURLRepositoryProtocol
    private let imageLoader: CatImageLoaderProtocol
    private let screener: CatImageScreenerProtocol
    private let prefetcher: CatImagePrefetcher

    // 画像取得関連
    static let maxImageCount = 300
    static let targetInitialDisplayCount = 30
    static let batchDisplayCount = 10

    // MARK: - Initialization

    init(
        repository: CatImageURLRepositoryProtocol,
        imageLoader: CatImageLoaderProtocol,
        screener: CatImageScreenerProtocol,
        prefetcher: CatImagePrefetcher
    ) {
        self.repository = repository
        self.imageLoader = imageLoader
        self.screener = screener
        self.prefetcher = prefetcher
    }

    private func fetchImages(requiredImageCount: Int) async throws -> [CatImageURLModel] {
        // 1. まずプリフェッチで足りるかチェック
        let prefetchedCount = await self.prefetcher.getPrefetchedCount()
        if prefetchedCount >= requiredImageCount {
            let images = await self.prefetcher.getPrefetchedImages(imageCount: requiredImageCount)
            await MainActor.run {
                print(
                    "画像表示完了: プリフェッチから\(images.count)枚追加 → 現在\(self.imageURLsToShow.count)枚表示中(残り\(prefetchedCount - images.count)枚)"
                )
            }
            return images
        }

        // 2. プリフェッチ不足時は直接取得を開始
        await MainActor.run {
            print("プリフェッチが不足しているため直接取得を開始: \(requiredImageCount)枚)")
        }

        var result: [CatImageURLModel] = []
        let maxRetry = 5  // 最大リトライ回数

        for _ in 0..<maxRetry where result.count < requiredImageCount {
            // 2.1 画像URLの取得
            let models = try await self.repository.getNextImageURLs(count: Self.batchDisplayCount)
            if models.isEmpty {
                throw NSError(domain: "GalleryViewModel",
                              code: -2,
                              userInfo: [NSLocalizedDescriptionKey: "URL repository exhausted"])
            }

            // 2.2 1枚ずつ処理
            for model in models {
                if result.count >= requiredImageCount { break }

                // 2.2.1 画像のダウンロード
                let loadedImages = try await self.imageLoader.loadImageData(from: [model])

                // 2.2.2 スクリーニングの実行
                let screenedModels = try await self.screener.screenImages(imageDataWithModels: loadedImages)

                if let screenedModel = screenedModels.first {
                    result.append(screenedModel)
                }
            }

            // 必要な枚数に達していない場合、追加で取得
            if result.count < requiredImageCount {
                await MainActor.run {
                    print("追加取得が必要: 現在\(result.count)枚 → 目標\(requiredImageCount)枚のため、次のバッチを取得します")
                }
            }
        }

        await MainActor.run {
            print("画像直接取得完了: \(result.count)枚追加 → 現在\(self.imageURLsToShow.count)枚表示中")
        }
        return result
    }

    func loadInitialImages() {
        if imageURLsToShow.isEmpty {
            let startTime = Date()
            print("初期画像の読み込み開始: 現在0枚 → 目標\(Self.targetInitialDisplayCount)枚")

            Task {
                await MainActor.run { self.isInitializing = true }
                do {
                    let numberOfBatches = 6
                    // targetInitialDisplayCount / numberOfBatches
                    for i in 0 ..< numberOfBatches {
                        let newImages = try await fetchImages(
                            requiredImageCount: Self
                                .targetInitialDisplayCount / numberOfBatches
                        )
                        await MainActor.run {
                            self.imageURLsToShow += newImages
                            print("バッチ\(i + 1)完了: \(newImages.count)枚追加 → 現在\(self.imageURLsToShow.count)枚表示中")
                        }

                        // 最初のバッチ完了時に時間を記録
                        if i == 0 {
                            let endTime = Date()
                            let timeInterval = endTime.timeIntervalSince(startTime)
                            print("初期画像の読み込み完了: \(String(format: "%.2f", timeInterval))秒")
                        }
                    }

                    await MainActor.run { self.isInitializing = false }
                    await prefetcher.startPrefetchingIfNeeded()
                } catch let error as NSError {
                    print("loadInitialImages でエラーが発生: \(error.localizedDescription)")
                    await MainActor.run {
                        self.errorMessage = error.localizedDescription
                        self.imageURLsToShow = []
                        self.isInitializing = false
                    }
                }
            }
        }
    }

    func fetchAdditionalImages() async {
        guard !self.isAdditionalFetching, !self.isInitializing else {
            print("既にローディング中のため、スキップします")
            return
        }
        await MainActor.run {
            self.isAdditionalFetching = true
            self.errorMessage = nil
        }

        do {
            let newImages = try await fetchImages(requiredImageCount: Self.batchDisplayCount)
            await MainActor.run {
                self.imageURLsToShow += newImages
                if self.imageURLsToShow.count > Self.maxImageCount {
                    print("最大表示枚数(\(Self.maxImageCount)枚)に到達したため、画像をクリアして再読み込みします")
                    self.clearDisplayedImages()
                    Task { await self.loadInitialImages() }
                    self.isAdditionalFetching = false
                    return
                }
            }
            await prefetcher.startPrefetchingIfNeeded()
        } catch let error as NSError {
            print("追加画像読み込みでエラーが発生: \(error.localizedDescription)")
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
        await MainActor.run { self.isAdditionalFetching = false }
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
