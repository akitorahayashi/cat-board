import CBModel
import Foundation

public protocol CatImageScreenerProtocol: Sendable {
    func screenImages(
        images: [(imageData: Data, model: CatImageURLModel)]
    ) async throws -> [CatImageURLModel]
}
