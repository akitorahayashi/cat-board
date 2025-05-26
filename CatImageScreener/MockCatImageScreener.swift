import CBModel
import CoreGraphics
import Foundation

public final class MockCatImageScreener: CatImageScreenerProtocol {
    public var screeningResult: [CatImageURLModel] = []
    public var screeningError: Error?

    public init() {}

    public func screenImages(
        cgImages: [CGImage],
        models: [CatImageURLModel]
    ) async throws -> [CatImageURLModel] {
        if let error = screeningError {
            throw error
        }
        return screeningResult
    }
} 