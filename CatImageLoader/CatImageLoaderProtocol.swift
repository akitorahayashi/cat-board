import CBModel
import Foundation

public protocol CatImageLoaderProtocol: Sendable {
    func getPrefetchedCount() async -> Int
    func getPrefetchedImages(count: Int) async -> [CatImageURLModel]
    func fetchImages(count: Int) async throws -> [CatImageURLModel]
    func startPrefetchingIfNeeded() async
} 