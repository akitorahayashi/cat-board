import CBModel
import Foundation

public protocol CatImageLoaderProtocol: Sendable {
    func loadImagesWithScreening(count: Int) async throws -> [CatImageURLModel]
    func getPrefetchedCount() async -> Int
    func getPrefetchedImages(imageCount: Int) async -> [CatImageURLModel]
    func startPrefetchingIfNeeded() async
}
