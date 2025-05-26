import CBModel
import CoreGraphics
import Foundation

public protocol CatImageScreenerProtocol: Sendable {
    func screenImages(
        cgImages: [CGImage],
        models: [CatImageURLModel]
    ) async throws -> [CatImageURLModel]
}
