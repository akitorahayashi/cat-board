import CatAPIClient
import CatImageLoader
import CatImagePrefetcher
import CatImageScreener
import CatImageURLRepository
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
    private let prefetcher: CatImagePrefetcherProtocol

    // 画像取得関連
    static let maxImageCount = 300
    static let targetInitialDisplayCount = 30
    static let batchDisplayCount = 10

    init(
        repository: CatImageURLRepositoryProtocol,
        imageLoader: CatImageLoaderProtocol,
        screener: CatImageScreenerProtocol,
        prefetcher: CatImagePrefetcherProtocol
    ) {
        self.repository = repository
        self.imageLoader = imageLoader
        self.screener = screener
        self.prefetcher = prefetcher
    }

    // 初期表示、またはViewを初期化した後に呼ぶ
    func loadInitialImages() {
        if imageURLsToShow.isEmpty {
            let startTime = Date()
            print("初期画像の読み込み開始: 現在0枚 → 目標\(Self.targetInitialDisplayCount)枚")

            Task {
                await MainActor.run { self.isInitializing = true }
                do {
                    try await fetchImagesInBatches(
                        totalImageCount: Self.targetInitialDisplayCount,
                        numberOfBatches: 6
                    ) { batchIndex, newImages in
                        Task { @MainActor in
                            self.imageURLsToShow += newImages
                            print("バッチ\(batchIndex + 1)完了: \(newImages.count)枚追加 → 現在\(self.imageURLsToShow.count)枚表示中")

                            // 最初のバッチ完了時に時間を記録
                            if batchIndex == 0 {
                                let endTime = Date()
                                let timeInterval = endTime.timeIntervalSince(startTime)
                                print("初回バッチ完了: \(String(format: "%.2f", timeInterval))秒")
                            }
                        }
                    }

                    Task {
                        do {
                            try await prefetcher.startPrefetchingIfNeeded()
                        } catch {
                            print("プリフェッチ開始でエラーが発生: \(error.localizedDescription)")
                        }
                    }

                } catch let error as NSError {
                    print("loadInitialImages でエラーが発生: \(error.localizedDescription)")
                    await MainActor.run {
                        self.errorMessage = error.localizedDescription
                        self.imageURLsToShow = []
                    }
                }

                // 処理完了後、必ずisInitializingをfalseに設定
                await MainActor.run { self.isInitializing = false }
            }
        }
    }

    // 追加取得
    func fetchAdditionalImages() async {
        guard !isAdditionalFetching, !isInitializing else {
            print("既にローディング中のため、スキップします")
            return
        }
        await MainActor.run {
            self.isAdditionalFetching = true
            self.errorMessage = nil
        }

        do {
            try await fetchImagesInBatches(
                totalImageCount: Self.batchDisplayCount,
                numberOfBatches: 2
            ) { batchIndex, newImages in
                Task { @MainActor in
                    self.imageURLsToShow += newImages
                    print("バッチ\(batchIndex + 1)完了: \(newImages.count)枚追加 → 現在\(self.imageURLsToShow.count)枚表示中")

                    if self.imageURLsToShow.count > Self.maxImageCount {
                        print("最大表示枚数(\(Self.maxImageCount)枚)に到達したため、画像をクリアして再読み込みします")
                        self.clearDisplayedImages()
                        Task { self.loadInitialImages() }
                        self.isAdditionalFetching = false
                        return
                    }
                }
            }

            Task {
                do {
                    try await prefetcher.startPrefetchingIfNeeded()
                } catch {
                    print("プリフェッチ開始でエラーが発生: \(error.localizedDescription)")
                }
            }

        } catch {
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
    }

    // MARK: - Private Methods

    // private func fetchImages を batch に分けて実行する
    private func fetchImagesInBatches(
        totalImageCount: Int,
        numberOfBatches: Int,
        onBatchComplete: @escaping (Int, [CatImageURLModel]) -> Void
    ) async throws {
        let baseImagesPerBatch = totalImageCount / numberOfBatches
        let remainder = totalImageCount % numberOfBatches

        for i in 0 ..< numberOfBatches {
            let imagesForThisBatch = baseImagesPerBatch + (i < remainder ? 1 : 0)
            let newImages = try await fetchImages(requiredImageCount: imagesForThisBatch)
            onBatchComplete(i, newImages)
        }
    }

    private func fetchImages(requiredImageCount: Int) async throws -> [CatImageURLModel] {
        // 1. プリフェッチで足りるかチェック
        let prefetchedCount = try await prefetcher.getPrefetchedCount()
        if prefetchedCount >= requiredImageCount {
            let urls = try await prefetcher.getPrefetchedImages(imageCount: requiredImageCount)
            let models = urls.map { CatImageURLModel(imageURL: $0) }
            await MainActor.run {
                print(
                    "画像表示完了: プリフェッチから\(models.count)枚追加 → 現在\(self.imageURLsToShow.count)枚表示中(残り\(prefetchedCount - models.count)枚)"
                )
            }
            return models
        }

        // 2. プリフェッチ不足時は直接取得を開始
        await MainActor.run {
            print("プリフェッチが不足しているため直接取得を開始: \(requiredImageCount)枚")
        }

        var result: [CatImageURLModel] = []
        let maxRetry = 5 // 最大リトライ回数

        for _ in 0 ..< maxRetry where result.count < requiredImageCount {
            // 2.1 画像URLの取得
            let urls = try await self.repository.getNextImageURLs(count: Self.batchDisplayCount)
            if urls.isEmpty {
                throw NSError(
                    domain: "GalleryViewModel",
                    code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "URL repository exhausted"]
                )
            }

            // 2.2 1枚ずつ処理
            for url in urls {
                if result.count >= requiredImageCount { break }

                // 2.2.1 画像のダウンロード
                let loadedImages = try await self.imageLoader.loadImageData(from: [url])

                // 2.2.2 スクリーニングの実行
                let screenedURLs = try await self.screener.screenImages(imageDataWithURLs: loadedImages)

                if let screenedURL = screenedURLs.first {
                    result.append(CatImageURLModel(imageURL: screenedURL))
                }
            }
        }

        let finalResult = result
        await MainActor.run {
            print("画像直接取得完了: \(finalResult.count)枚追加 → 現在\(self.imageURLsToShow.count)枚表示中")
        }
        return finalResult
    }
}
