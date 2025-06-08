import CatURLImageModel
import Foundation

public actor MockCatImageScreener: CatImageScreenerProtocol {
    private let error: Error?

    public var isScreeningEnabled: Bool = true

    public init(
        error: Error? = nil
    ) {
        self.error = error
    }

    public func setIsScreeningEnabled(_ enabled: Bool) {
        isScreeningEnabled = enabled
    }

    public func screenImages(
        imageDataWithModels: [(imageData: Data, model: CatImageURLModel)]
    ) async throws -> [CatImageURLModel] {
        if let error {
            throw error
        }

        // スクリーニングが無効の場合は全ての画像をそのまま返す
        if !isScreeningEnabled {
            return imageDataWithModels.map(\.model)
        }

        // 完全にランダムで50%の確率で画像を返す
        return imageDataWithModels.compactMap { model in
            Bool.random() ? model.model : nil
        }
    }
}
