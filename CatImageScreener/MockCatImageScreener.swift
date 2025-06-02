import CatImageScreener
import CBModel
import Foundation

public final class MockCatImageScreener: CatImageScreenerProtocol {
    private let mockImages: [CatImageURLModel]
    private let error: Error?

    public init(mockImages: [CatImageURLModel] = [], error: Error? = nil) {
        self.mockImages = mockImages
        self.error = error
    }

    public func screenImages(imageDataWithModels _: [(imageData: Data, model: CatImageURLModel)]) async throws
        -> [CatImageURLModel]
    {
        if let error {
            throw error
        }
        return mockImages
    }
}
