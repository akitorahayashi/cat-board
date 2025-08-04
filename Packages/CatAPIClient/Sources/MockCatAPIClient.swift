import Foundation

public struct MockCatAPIClient: CatAPIClientProtocol {
    private let error: Error?

    public init(error: Error? = nil) {
        self.error = error
    }

    public func fetchImageURLs(totalCount: Int, batchSize _: Int = 10) async throws -> [URL] {
        if let error {
            throw error
        }

        return (0 ..< totalCount).compactMap { index in
            URL(string: "https://example.com/cat\(index).jpg")
        }
    }
}
