import CBModel
import Foundation

public final class MockCatAPIClient: CatAPIClientProtocol {
    public var fetchImageURLsError: Error?
    public var mockImageURLs: [CatImageURLModel] = []

    public init() {}

    public func fetchImageURLs(totalCount: Int, batchSize _: Int) async throws -> [CatImageURLModel] {
        if let error = fetchImageURLsError {
            throw error
        }

        return Array(mockImageURLs.prefix(totalCount))
    }
}
