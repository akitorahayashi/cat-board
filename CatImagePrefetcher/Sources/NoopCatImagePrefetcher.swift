import CatImageLoader
import CatImageScreener
import CatImageURLRepository
import CatURLImageModel
import Foundation

// プリフェッチを無効化
public actor NoopCatImagePrefetcher: CatImagePrefetcherProtocol {
    private let repository: CatImageURLRepositoryProtocol
    private let imageLoader: CatImageLoaderProtocol
    private let screener: CatImageScreenerProtocol

    public init(
        repository: CatImageURLRepositoryProtocol,
        imageLoader: CatImageLoaderProtocol,
        screener: CatImageScreenerProtocol
    ) {
        self.repository = repository
        self.imageLoader = imageLoader
        self.screener = screener
    }

    public func getPrefetchedCount() async throws -> Int {
        0
    }

    public func getPrefetchedImages(imageCount _: Int) async throws -> [CatImageURLModel] {
        []
    }

    public func startPrefetchingIfNeeded() async throws {}
}
