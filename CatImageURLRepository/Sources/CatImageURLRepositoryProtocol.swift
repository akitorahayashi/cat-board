import CatAPIClient
import Foundation
import SwiftData

public protocol CatImageURLRepositoryProtocol: Sendable {
    func getNextImageURLs(count: Int) async throws -> [URL]
}
