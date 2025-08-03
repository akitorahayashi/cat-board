import Foundation
import ScaryCatScreeningKit

public actor CatImageScreener: CatImageScreenerProtocol {
    private var screener: ScaryCatScreener?
    private static let screeningProbabilityThreshold: Float = 0.85
    private static let enableLogging = false
    private let screeningSettings: ScreeningSettings

    public init(screeningSettings: ScreeningSettings) {
        self.screeningSettings = screeningSettings
        screener = nil
    }

    public func getScreener() async throws -> ScaryCatScreener? {
        if let screener {
            return screener
        } else {
            do {
                let newScreener = try await ScaryCatScreener(enableLogging: Self.enableLogging)
                screener = newScreener
                return newScreener
            } catch let error as NSError {
                print("ScaryCatScreener の初期化に失敗しました: \(error.localizedDescription)")
                print("エラーコード: \(error.code), ドメイン: \(error.domain)")
                if let underlying = error.userInfo[NSUnderlyingErrorKey] as? Error {
                    print("原因: \(underlying.localizedDescription)")
                }
                return nil
            }
        }
    }

    public nonisolated func screenImages(
        imageDataWithURLs: [(imageData: Data, imageURL: URL)]
    ) async throws -> [URL] {
        guard !imageDataWithURLs.isEmpty else { return [] }

        let allURLs = imageDataWithURLs.map(\.imageURL)

        // スクリーニングが無効な場合
        if !await screeningSettings.isScreeningEnabled {
            return allURLs
        }

        do {
            let screener = try await getScreener()

            // スクリーナーがnilの場合は全ての画像を安全として返す
            guard let screener else {
                print("スクリーナーの初期化に失敗したため、全ての画像を安全として返します")
                return allURLs
            }

            let imageDataList = imageDataWithURLs.map(\.imageData)
            let probabilityThreshold = Self.screeningProbabilityThreshold
            let enableLogging = Self.enableLogging

            let screeningResults = try await screener.screen(
                imageDataList: imageDataList,
                probabilityThreshold: probabilityThreshold,
                enableLogging: enableLogging
            )

            if await screeningSettings.scaryMode {
                // 怖いモードの場合、unsafeResultsを使用
                let results = screeningResults.unsafeResults.compactMap { result in
                    allURLs[result.originalIndex]
                }
                if Self.enableLogging {
                    print("スクリーニング結果: \(imageDataWithURLs.count)枚中\(results.count)枚が危険と判定")
                    print(screeningResults.generateDetailedReport())
                }
                return results
            } else {
                // 通常モードの場合、safeResultsを使用
                let results = screeningResults.safeResults.compactMap { result in
                    allURLs[result.originalIndex]
                }
                if Self.enableLogging {
                    print("スクリーニング結果: \(imageDataWithURLs.count)枚中\(results.count)枚が安全と判定")
                    print(screeningResults.generateDetailedReport())
                }
                return results
            }
        } catch let error as NSError {
            print("スクリーニング処理でエラーが発生しました: \(error.localizedDescription)")
            print("エラーコード: \(error.code), ドメイン: \(error.domain)")
            if let underlying = error.userInfo[NSUnderlyingErrorKey] as? Error {
                print("原因: \(underlying.localizedDescription)")
            }
            // エラーが発生した場合、全ての画像を安全として返す
            return allURLs
        }
    }
}
