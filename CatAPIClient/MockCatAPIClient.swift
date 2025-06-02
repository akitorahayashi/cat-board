import Foundation
import CBModel

public struct MockCatAPIClient: CatAPIClientProtocol {
    private let totalCount: Int
    private let error: Error?

    public init(totalCount: Int = 10, error: Error? = nil) {
        self.totalCount = totalCount
        self.error = error
    }

    public func fetchImageURLs(totalCount: Int, batchSize: Int) async throws -> [CatImageURLModel] {
        if let error {
            throw error
        }

        let count = min(totalCount, self.totalCount)
        return (0..<count).map { index in
            CatImageURLModel(imageURL: "https://example.com/cat\(index).jpg")
        }
    }
}
