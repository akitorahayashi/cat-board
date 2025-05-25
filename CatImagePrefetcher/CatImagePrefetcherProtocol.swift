import CBModel
import Foundation

public protocol CatImagePrefetcherProtocol {
    func getPrefetchedCount() -> Int
    func getPrefetchedImages(count: Int) -> [CatImageURLModel]
    func fetchImages(count: Int) async throws -> [CatImageURLModel]
    func startPrefetchingIfNeeded() async
} 