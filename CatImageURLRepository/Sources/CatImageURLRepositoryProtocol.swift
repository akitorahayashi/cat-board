import CatAPIClient
import SwiftData

public protocol CatImageURLRepositoryProtocol: Sendable {
    func getNextImageURLs(count: Int) async throws -> [URL]
}
