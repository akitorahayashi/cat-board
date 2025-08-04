import Foundation

public actor MockCatImageScreener: CatImageScreenerProtocol {
    private let error: Error?
    private let screeningSettings: ScreeningSettings

    public init(screeningSettings: ScreeningSettings, error: Error? = nil) {
        self.screeningSettings = screeningSettings
        self.error = error
    }

    public func screenImages(
        imageDataWithURLs: [(imageData: Data, imageURL: URL)]
    ) async throws -> [URL] {
        if let error {
            throw error
        }

        let allURLs = imageDataWithURLs.map(\.imageURL)
        // スクリーニングが無効の場合は全ての画像をそのまま返す
        if !screeningSettings.isScreeningEnabled {
            return allURLs
        }

        // 決定論的なスクリーニング：インデックスが偶数の画像を返す
        return imageDataWithURLs.enumerated().compactMap { index, element in
            index % 2 == 0 ? element.imageURL : nil
        }
    }
}
