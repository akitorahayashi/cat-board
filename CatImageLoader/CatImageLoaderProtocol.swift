import CBModel
import Foundation

public protocol CatImageLoaderProtocol: Sendable {
    func getPrefetchedCount() async -> Int
    func getPrefetchedImages(imageCount: Int) async -> [CatImageURLModel]
    func loadImagesDirectlyAndScreen(imageCount: Int) async throws -> [CatImageURLModel]
    func startPrefetchingIfNeeded() async
} 