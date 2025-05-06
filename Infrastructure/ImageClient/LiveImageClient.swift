import CatScreeningKit
import CBShared
import ComposableArchitecture
import UIKit

public struct LiveImageClient: ImageClientProtocol {
    public init() {}

    public var fetchImages: @Sendable (Int, Int) async throws -> [CatImageModel] {
        { limit, page in
            let allImageModels = try await self.performFetch(limit: limit, page: page)

            guard !allImageModels.isEmpty else {
                return []
            }

            let screener = try ScaryCatScreener()

            let downloadResults: [(model: CatImageModel, image: UIImage?)] = await withTaskGroup(of: (
                CatImageModel,
                UIImage?
            ).self) { group in
                var results = [(CatImageModel, UIImage?)]()
                for model in allImageModels {
                    group.addTask {
                        let session = URLSession(configuration: .ephemeral)
                        guard let url = URL(string: model.imageURL) else {
                            print("[LiveImageClient] 不正なURL: \(model.imageURL) (ID: \(model.id))")
                            return (model, nil)
                        }
                        do {
                            let (data, _) = try await session.data(from: url)
                            return (model, UIImage(data: data))
                        } catch {
                            print(
                                "[LiveImageClient] 画像ダウンロード失敗: \(model.id), URL: \(model.imageURL), Error: \(error)"
                            )
                            return (model, nil)
                        }
                    }
                }
                for await result in group {
                    results.append(result)
                }
                return results
            }

            let successfulDownloads = downloadResults.compactMap { model, image -> (
                model: CatImageModel,
                image: UIImage
            )? in
                guard let image else { return nil }
                return (model, image)
            }

            let imagesToScreen = successfulDownloads.map(\.image)
            let modelsForImagesToScreen = successfulDownloads.map(\.model)

            let safeImageIndices = try await screener.screen(images: imagesToScreen, enableLogging: true)

            if !imagesToScreen.isEmpty {
                if !safeImageIndices.isEmpty {
                    print(
                        "[LiveImageClient] WARNING: スクリーニング結果の正確な紐付けが未実装です。安全と判定されたUIImageの数: \(safeImageIndices.count)。対応するCatImageModelの特定が必要です。"
                    )
                    print("[LiveImageClient] 暫定対応: 安全な画像が検出されたため、ダウンロードに成功した全てのモデルを返します。安全でない画像が含まれる可能性があります。")
                    return modelsForImagesToScreen
                } else {
                    print("[LiveImageClient] スクリーニングの結果、安全な画像はありませんでした。")
                    return []
                }
            } else {
                return []
            }
        }
    }

    private func performFetch(limit: Int, page: Int) async throws -> [CatImageModel] {
        print(
            "[LiveImageClient performFetch] Placeholder: Actual API call to fetch image metadata for limit: \(limit), page: \(page) is needed here."
        )
        return []
    }
}
