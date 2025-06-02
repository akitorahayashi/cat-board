import Foundation
import CBModel

public struct MockCatAPIClient: CatAPIClientProtocol {
    private let error: Error?

    public init(error: Error? = nil) {
        self.error = error
    }

    public func fetchImageURLs(totalCount: Int, batchSize: Int = 10) async throws -> [CatImageURLModel] {
        if let error {
            throw error
        }

        return (0..<totalCount).map { index in
            CatImageURLModel(imageURL: "https://example.com/cat\(index).jpg")
        }
    }
}
