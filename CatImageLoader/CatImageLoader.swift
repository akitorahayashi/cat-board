import CBModel
import CatAPIClient
import CatImageURLRepository
import CatImageScreener
import Kingfisher
import SwiftUI
import SwiftData

public actor CatImageLoader: CatImageLoaderProtocol {
    private let repository: CatImageURLRepositoryProtocol
    private let imageClient: CatAPIClient
    private let screener: CatImageScreener
    private var isPrefetching: Bool = false
    private var prefetchTask: Task<Void, Never>?
    private var prefetchedImages: [CatImageURLModel] = []
    private let modelContainer: ModelContainer

    // プリフェッチ関連の定数
    private static let prefetchBatchCount = 10 // 一回のプリフェッチでロードして screener に通す枚数
    private static let targetPrefetchCount = 150 // プリフェッチの目標枚数
    private static let maxFetchAttempts = 30 // 最大取得試行回数
    private static let maxRetryCount = 3 // 最低限必要な枚数を確保するための最大リトライ回数

    public init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        self.repository = CatImageURLRepository(modelContainer: modelContainer)
        self.imageClient = CatAPIClient()
        self.screener = CatImageScreener()
    }

    deinit {
        prefetchTask?.cancel()
        KingfisherManager.shared.cache.clearMemoryCache()
    }

    public func getPrefetchedCount() async -> Int {
        prefetchedImages.count
    }

    public func getPrefetchedImages(imageCount: Int) async -> [CatImageURLModel] {
        let batchCount = min(imageCount, prefetchedImages.count)
        let batch = Array(prefetchedImages.prefix(batchCount))
        prefetchedImages.removeFirst(batchCount)
        return batch
    }

    // MARK: - Private Methods

    private func getPrefetchURLs(count: Int) async throws -> [CatImageURLModel] {
        print("プリフェッチ用URL取得開始: \(count)件")
        let urls = try await repository.getNextImageURLs(count: count)
        return urls
    }

    private func getDirectURLs(count: Int) async throws -> [CatImageURLModel] {
        print("直接実行用URL取得開始: \(count)件")
        let urls = try await repository.getNextImageURLs(count: count)
        return urls
    }

    private func loadImages(from models: [CatImageURLModel]) async throws -> [CatImageURLModel] {
        var loadedModels: [CatImageURLModel] = []
        
        for (index, item) in models.enumerated() {
            guard let url = URL(string: item.imageURL) else {
                print("無効なURL: \(item.imageURL)")
                continue
            }
            
            do {
                let result = try await KingfisherManager.shared.downloader.downloadImage(
                    with: url,
                    options: [
                        .requestModifier(AnyModifier { request in
                            var r = request
                            r.timeoutInterval = 10
                            return r
                        }),
                        .diskCacheExpiration(.expired)
                    ]
                )
                
                if result.image.cgImage != nil {
                    loadedModels.append(item)
                }
            } catch let error as NSError {
                let errorType = error.domain == NSURLErrorDomain ? "ネットワーク" : "その他"
                print("画像のダウンロードに失敗 [\(index + 1)/\(models.count)]: \(errorType)エラー (\(item.imageURL))")
                continue
            }
        }
        
        print("ダウンロード結果: \(models.count)件中\(loadedModels.count)件成功")
        return loadedModels
    }

    // MARK: - Public Methods

    public func loadImagesWithScreening(count: Int) async throws -> [CatImageURLModel] {
        print("直接実行開始: \(count)枚の画像を取得します")
        let urls = try await getDirectURLs(count: count)
        let loadedImages = try await loadImages(from: urls)
        
        if loadedImages.isEmpty {
            print("取得可能な画像がありませんでした")
            return []
        }
        
        // スクリーニング実行
        var cgImages: [CGImage] = []
        for model in loadedImages {
            guard let url = URL(string: model.imageURL) else { continue }
            do {
                let result = try await KingfisherManager.shared.downloader.downloadImage(with: url)
                if let cgImage = result.image.cgImage {
                    cgImages.append(cgImage)
                }
            } catch {
                continue
            }
        }
        
        let filteredModels = try await screener.screenImages(
            cgImages: cgImages,
            models: loadedImages
        )
        
        print("スクリーニング結果: \(loadedImages.count)枚中\(filteredModels.count)枚通過")
        return filteredModels
    }

    public func startPrefetchingIfNeeded() async {
        guard !isPrefetching else { return }
        guard prefetchedImages.count < Self.targetPrefetchCount else { return }
        
        prefetchTask?.cancel()
        isPrefetching = true

        prefetchTask = Task { [self] in
            do {
                await self.prefetchImages()
            } catch {
                print("プリフェッチ中にエラーが発生: \(error.localizedDescription)")
            }
            await setPrefetching(false)
        }
    }

    private func setPrefetching(_ value: Bool) {
        isPrefetching = value
    }

    private func prefetchImages() async {
        do {
            let remainingCount = Self.targetPrefetchCount - prefetchedImages.count
            print("プリフェッチ開始: 現在\(prefetchedImages.count)枚 → 目標\(Self.targetPrefetchCount)枚 (残り\(remainingCount)枚)")

            var totalFetched = 0
            var totalScreened = 0

            while prefetchedImages.count < Self.targetPrefetchCount && totalFetched < Self.maxFetchAttempts * Self.prefetchBatchCount {
                if Task.isCancelled {
                    print("プリフェッチがキャンセルされました")
                    break
                }

                let urls = try await getPrefetchURLs(count: Self.prefetchBatchCount)
                let loadedImages = try await loadImages(from: urls)
                
                totalFetched += Self.prefetchBatchCount
                totalScreened += loadedImages.count

                prefetchedImages += loadedImages

                if prefetchedImages.count >= Self.targetPrefetchCount {
                    print("プリフェッチ完了: 目標\(Self.targetPrefetchCount)枚に達しました")
                    break
                }
            }

            if prefetchedImages.count < Self.targetPrefetchCount {
                print("プリフェッチ終了: 最大試行回数に達しました (取得\(totalFetched)枚, 通過\(totalScreened)枚, 現在\(prefetchedImages.count)枚)")
            }
        } catch let error as NSError {
            print("プリフェッチ中にエラーが発生: \(error.localizedDescription)")
        }
    }
} 

