import CatURLImageModel
import Foundation

public actor MockCatImageScreener: CatImageScreenerProtocol {
    private let error: Error?
    private let screeningSettings: ScreeningSettings

    public init(screeningSettings: ScreeningSettings, error: Error? = nil) {
        self.screeningSettings = screeningSettings
        self.error = error
    }

    public func screenImages(
        imageDataWithModels: [(imageData: Data, model: CatImageURLModel)]
    ) async throws -> [CatImageURLModel] {
        if let error {
            throw error
        }

        // スクリーニングが無効の場合は全ての画像をそのまま返す
        if !screeningSettings.isScreeningEnabled {
            return imageDataWithModels.map(\.model)
        }

        // 完全にランダムで50%の確率で画像を返す
        return imageDataWithModels.compactMap { model in
            Bool.random() ? model.model : nil
        }
    }
}
