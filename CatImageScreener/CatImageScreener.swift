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

    private func getScreener() async throws -> ScaryCatScreener {
        if let screener {
            return screener
        } else {
            do {
                let newScreener = try await ScaryCatScreener(enableLogging: Self.enableLogging)
                screener = newScreener
                return newScreener
            } catch let error as NSError {
                if Self.enableLogging {
                    print("ScaryCatScreener の初期化に失敗しました: \(error.localizedDescription)")
                    print("エラーコード: \(error.code), ドメイン: \(error.domain)")
                    if let underlying = error.userInfo[NSUnderlyingErrorKey] as? Error {
                        print("原因: \(underlying.localizedDescription)")
                    }
                }
                throw error
            }
        }
    }

    public func screenImages(
        images: [(imageData: Data, model: CatImageURLModel)]
    ) async throws -> [CatImageURLModel] {
        guard !images.isEmpty else { return [] }

        do {
            let screener = try await getScreener()

            let screeningResults = try await screener.screen(
                imageDataList: images.map(\.imageData),
                probabilityThreshold: Self.screeningProbabilityThreshold,
                enableLogging: Self.enableLogging
            )

            if !Self.isScreeningEnabled {
                return images.map(\.model)
            }

            // 画像データとモデルのマッピングを作成
            let imageDataToModel = Dictionary(uniqueKeysWithValues: images.map { ($0.imageData, $0.model) })

            if Self.scaryMode {
                // 怖いモードの場合、unsafeResultsを使用
                let results = screeningResults.unsafeResults.compactMap { result in
                    imageDataToModel[result.imageData]
                }
                if Self.enableLogging {
                    print("スクリーニング結果: \(images.count)枚中\(results.count)枚が危険と判定")
                    print(screeningResults.generateDetailedReport())
                }
                return results
            } else {
                // 通常モードの場合、safeResultsを使用
                let results = screeningResults.safeResults.compactMap { result in
                    imageDataToModel[result.imageData]
                }
                if Self.enableLogging {
                    print("スクリーニング結果: \(images.count)枚中\(results.count)枚が安全と判定")
                    print(screeningResults.generateDetailedReport())
                }
                return results
            }
        } catch let error as NSError {
            if Self.enableLogging {
                print("スクリーニング処理でエラーが発生しました: \(error.localizedDescription)")
                print("エラーコード: \(error.code), ドメイン: \(error.domain)")
                if let underlying = error.userInfo[NSUnderlyingErrorKey] as? Error {
                    print("原因: \(underlying.localizedDescription)")
                }
            }
            throw error
        }
    }
}
