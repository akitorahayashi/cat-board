import Foundation
import SwiftData

public protocol CatImagePrefetcherProtocol {
    func getPrefetchedCount() async throws -> Int
    func getPrefetchedImages(imageCount: Int) async throws -> [URL]
    func startPrefetchingIfNeeded() async throws
    func clearAllPrefetchedImages() async throws
}
