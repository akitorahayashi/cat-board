import CatAPIClient
import CBModel
import Foundation

public protocol CatImageURLRepositoryProtocol: Sendable {
    func getNextImageURLs(count: Int) async throws -> [CatImageURLModel]
}
