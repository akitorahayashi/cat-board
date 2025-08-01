import CatURLImageModel

public protocol CatImagePrefetcherProtocol {
    func getPrefetchedCount() async throws -> Int
    func getPrefetchedImages(imageCount: Int) async throws -> [CatImageURLModel]
    func startPrefetchingIfNeeded() async throws
    func clearAllPrefetchedImages() async throws
}
