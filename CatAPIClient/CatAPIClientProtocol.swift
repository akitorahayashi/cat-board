import CBModel
import Foundation

public protocol CatAPIClientProtocol: Sendable {
    func fetchImageURLs(totalCount: Int, batchSize: Int) async throws -> [CatImageURLModel]
} 