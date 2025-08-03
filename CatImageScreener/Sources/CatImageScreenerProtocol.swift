import Foundation

public protocol CatImageScreenerProtocol: Sendable {
    func screenImages(
        imageDataWithURLs: [(imageData: Data, imageURL: URL)]
    ) async throws -> [URL]
}
