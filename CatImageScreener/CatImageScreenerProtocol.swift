import CatURLImageModel
import Foundation

public protocol CatImageScreenerProtocol: Sendable {
    func screenImages(
        imageDataWithModels: [(imageData: Data, model: CatImageURLModel)]
    ) async throws -> [CatImageURLModel]
}
