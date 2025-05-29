import CatAPIClient
import CatImageScreener
import CBModel
import Foundation

public struct MockCatImageLoader: CatImageLoaderProtocol {
    public var loadImagesWithScreeningResult: [CatImageURLModel] = []
    public var loadImagesWithScreeningError: Error?
    public var prefetchedImages: [CatImageURLModel] = []
    public var prefetchedCount: Int = 0

    public init() {}

    public func loadImagesWithScreening(count: Int) async throws -> [CatImageURLModel] {
        if let error = loadImagesWithScreeningError {
            throw error
        }
        let result = Array(loadImagesWithScreeningResult.prefix(count))
        print("MockCatImageLoader: 要求数\(count)枚に対して\(result.count)枚を返却")
        return result
    }

    public func getPrefetchedCount() async -> Int {
        prefetchedCount
    }

    public func getPrefetchedImages(imageCount: Int) async -> [CatImageURLModel] {
        Array(prefetchedImages.prefix(imageCount))
    }

    public func startPrefetchingIfNeeded() async {
        // プリフェッチは無効化
    }
}
