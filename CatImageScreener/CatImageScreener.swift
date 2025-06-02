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
        print("スクリーニング開始: \(imageDataWithModels.count)枚")
        guard !imageDataWithModels.isEmpty else { return [] }

        do {
            print("スクリーナーの取得を開始")
            let screener = try await getScreener()
            print("スクリーナーの取得完了: \(screener != nil ? "成功" : "失敗")")

            // スクリーナーがnilの場合は全ての画像を安全として返す
            guard let screener else {
                print("スクリーナーの初期化に失敗したため、全ての画像を安全として返します")
                return imageDataWithModels.map(\.model)
            }

            print("スクリーニング処理を開始")
            let screeningResults = try await screener.screen(
                imageDataList: imageDataWithModels.map(\.imageData),
                probabilityThreshold: Self.screeningProbabilityThreshold,
                enableLogging: Self.enableLogging
            )
            print("スクリーニング処理が完了")

            if !Self.isScreeningEnabled {
                print("スクリーニング終了: スクリーニング無効のため全ての画像を通過")
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
                print("スクリーニング終了: 危険と判定された\(results.count)枚を返却")
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
                print("スクリーニング終了: 安全と判定された\(results.count)枚を返却")
                return results
            }
        } catch let error as NSError {
            print("スクリーニング処理でエラーが発生しました: \(error.localizedDescription)")
            print("エラーコード: \(error.code), ドメイン: \(error.domain)")
            if let underlying = error.userInfo[NSUnderlyingErrorKey] as? Error {
                print("原因: \(underlying.localizedDescription)")
            }
            // エラーが発生した場合も全ての画像を安全として返す
            print("スクリーニング終了: エラー発生のため全ての画像を安全として返却")
            return imageDataWithModels.map(\.model)
        }
    }
}
