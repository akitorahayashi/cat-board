import CatAPIClient
import CBModel
import Foundation

public final actor MockCatImageURLRepository: CatImageURLRepositoryProtocol {
    public var getNextImageURLsResult: [CatImageURLModel] = []
    public var getNextImageURLsError: Error?

    public init() {}

    public func getNextImageURLs(count: Int) async throws -> [CatImageURLModel] {
        if let error = getNextImageURLsError {
            throw error
        }
        return Array(getNextImageURLsResult.prefix(count))
    }
}
