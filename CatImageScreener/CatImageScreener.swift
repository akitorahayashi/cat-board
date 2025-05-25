import CBModel
import ScaryCatScreeningKit
import CoreGraphics
import Foundation

public actor CatImageScreener {
    private var screener: ScaryCatScreener?
    private static let screeningProbabilityThreshold: Float = 0.85
    private static let isScreeningEnabled = true
    private static let scaryMode = false

    public init() {}

    public func screenImages(
        cgImages: [CGImage],
        models: [CatImageURLModel]
    ) async throws -> [CatImageURLModel] {
        guard !cgImages.isEmpty else { return [] }
        guard cgImages.count == models.count else {
            throw NSError(domain: "CatImageScreener", code: -1, userInfo: [NSLocalizedDescriptionKey: "画像とモデルの数が一致しません"])
        }

        if screener == nil {
            screener = try await ScaryCatScreener()
        }

        let screeningResults = try await screener?.screen(
            cgImages: cgImages,
            probabilityThreshold: Self.screeningProbabilityThreshold,
            enableLogging: false
        )

        guard let results = screeningResults else {
            return models
        }

        let overallResults = SCSOverallScreeningResults(results: results)
        if !Self.isScreeningEnabled {
            return models
        }

        if Self.scaryMode {
            // 怖いモードの場合、unsafeResultsを使用
            return overallResults.unsafeResults.map { result in
                models[cgImages.firstIndex(of: result.cgImage) ?? 0]
            }
        } else {
            // 通常モードの場合、safeResultsを使用
            return overallResults.safeResults.map { result in
                models[cgImages.firstIndex(of: result.cgImage) ?? 0]
            }
        }
    }

    public func clearCache() {
        screener = nil
    }
} 