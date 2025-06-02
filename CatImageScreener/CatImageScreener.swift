import CBModel
import CoreGraphics
import Foundation
import ScaryCatScreeningKit

public actor CatImageScreener: CatImageScreenerProtocol {
    private var screener: ScaryCatScreener?
    private static let screeningProbabilityThreshold: Float = 0.85
    private static let isScreeningEnabled = true
    private static let scaryMode = false
    private static let enableLogging = false

    public init() {
        screener = nil
    }

    private func getScreener() async throws -> ScaryCatScreener? {
        if let screener {
            return screener
        } else {
            do {
                // ScaryCatScreenerの初期化でBundle.moduleを使用するように修正済みのことを前提とする
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
        imageDataWithModels: [(imageData: Data, model: CatImageURLModel)]
    ) async throws -> [CatImageURLModel] {
        guard !imageDataWithModels.isEmpty else { return [] }

        do {
            let screener = try await getScreener()
            
            // スクリーナーがnilの場合は全ての画像を安全として返す
            guard let screener else {
                print("スクリーナーの初期化に失敗したため、全ての画像を安全として返します")
                return imageDataWithModels.map(\.model)
            }

            let imageDataList = imageDataWithModels.map(\.imageData)
            let probabilityThreshold = Self.screeningProbabilityThreshold
            let enableLogging = Self.enableLogging

            let screeningResults = try await screener.screen(
                imageDataList: imageDataList,
                probabilityThreshold: probabilityThreshold,
                enableLogging: enableLogging
            )

            if !Self.isScreeningEnabled {
                return imageDataWithModels.map(\.model)
            }

            // スクリーニング結果から元のモデルを取得するために、モデルの配列を準備
            let models = imageDataWithModels.map(\.model)

            if Self.scaryMode {
                // 怖いモードの場合、unsafeResultsを使用
                let results = screeningResults.unsafeResults.compactMap { result in
                    models[result.originalIndex]
                }
                if Self.enableLogging {
                    print("スクリーニング結果: \(imageDataWithModels.count)枚中\(results.count)枚が危険と判定")
                    print(screeningResults.generateDetailedReport())
                }
                return results
            } else {
                // 通常モードの場合、safeResultsを使用
                let results = screeningResults.safeResults.compactMap { result in
                    models[result.originalIndex]
                }
                if Self.enableLogging {
                    print("スクリーニング結果: \(imageDataWithModels.count)枚中\(results.count)枚が安全と判定")
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
            return imageDataWithModels.map(\.model)
        }
    }
}
