import CBModel
import Foundation

public final class MockCatImageScreener: CatImageScreenerProtocol {
    public var screeningResult: [CatImageURLModel] = []
    public var screeningError: Error?

    public init() {}

    public func screenImages(
        images _: [(imageData: Data, model: CatImageURLModel)]
    ) async throws -> [CatImageURLModel] {
        if let error = screeningError {
            throw error
        }
        return screeningResult
    }
}
