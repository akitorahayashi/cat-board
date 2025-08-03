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

        // 決定論的なスクリーニング：インデックスが偶数の画像を返す
        return imageDataWithModels.enumerated().compactMap { index, element in
            index % 2 == 0 ? element.model : nil
        }
    }
}
