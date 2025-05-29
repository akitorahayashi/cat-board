@preconcurrency import CBModel
import Foundation

public struct MockCatAPIClient: CatAPIClientProtocol {
    private let mockImageURLs: [CatImageURLModel]
    private let error: Error?

    public init(mockImageURLs: [CatImageURLModel] = [], error: Error? = nil) {
        self.mockImageURLs = mockImageURLs
        self.error = error
    }

    public func fetchImageURLs(totalCount: Int, batchSize _: Int) async throws -> [CatImageURLModel] {
        if let error {
            throw error
        }

        return Array(mockImageURLs.prefix(totalCount))
    }
}
