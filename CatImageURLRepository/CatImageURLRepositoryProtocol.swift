import CatAPIClient
import CBModel
import Foundation

public protocol CatImageURLRepositoryProtocol {
    func getNextImageURLs(count: Int) async throws -> [CatImageURLModel]
}
