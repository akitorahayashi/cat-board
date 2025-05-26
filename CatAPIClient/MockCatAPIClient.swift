import CBModel
import Foundation

public final class MockCatAPIClient: CatAPIClientProtocol {
    public var fetchImageURLsError: Error?
    public var mockImageURLs: [CatImageURLModel] = []
    public var shouldThrowError: Bool = false

    public init() {}

    public func fetchImageURLs(totalCount: Int, batchSize _: Int) async throws -> [CatImageURLModel] {
        if shouldThrowError {
            throw NSError(domain: "MockError", code: -1, userInfo: nil)
        }

        return Array(mockImageURLs.prefix(totalCount))
    }
}
