import CatImageScreener
import CBModel
import Foundation

public actor MockCatImageScreener: CatImageScreenerProtocol {
    private let error: Error?
    private let screeningProbability: Float

    public init(
        error: Error? = nil,
        screeningProbability: Float = 0.5
    ) {
        self.error = error
        self.screeningProbability = screeningProbability
    }

    public func screenImages(
        imageDataWithModels: [(imageData: Data, model: CatImageURLModel)]
    ) async throws -> [CatImageURLModel] {
        if let error {
            throw error
        }

        // ランダムに指定された確率で画像を返す
        return imageDataWithModels.compactMap { model in
            Float.random(in: 0...1) < screeningProbability ? model.model : nil
        }
    }
}
