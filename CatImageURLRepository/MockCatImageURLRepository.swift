import CatAPIClient
import CBModel
import Foundation

public struct MockCatImageURLRepository: CatImageURLRepositoryProtocol {
    private let mockImageURLs: [CatImageURLModel]
    private let error: Error?

    public init(mockImageURLs: [CatImageURLModel] = [], error: Error? = nil) {
        self.mockImageURLs = mockImageURLs
        self.error = error
    }

    public func getNextImageURLs(count: Int) async throws -> [CatImageURLModel] {
        if let error = error {
            throw error
        }
        return Array(mockImageURLs.prefix(count))
    }
}
