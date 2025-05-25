import CBModel
import CatAPIClient
import Foundation

public protocol CatImageURLRepositoryProtocol {
    func getNextImageURLs(count: Int) async throws -> [CatImageURLModel]
} 
