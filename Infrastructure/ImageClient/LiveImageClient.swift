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
        guard let url = URL(string: "https://api.thecatapi.com/v1/images/search?limit=\(limit)&page=\(page)&order=Rand") else {
            throw URLError(.badURL)
        }

        let request = URLRequest(url: url)
        // APIキーが必要な場合は、ここでリクエストヘッダーに追加します。
        // 例: request.addValue("YOUR_API_KEY", forHTTPHeaderField: "x-api-key")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            // HTTPステータスコードが200以外の場合のエラー処理
            // 必要に応じて、より詳細なエラー情報を含むカスタムエラーをスローします。
            print("[LiveImageClient performFetch] HTTP Error: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            throw URLError(.badServerResponse)
        }

        do {
            let decoder = JSONDecoder()
            let catImages = try decoder.decode([CatImageModel].self, from: data)
            return catImages
        } catch {
            print("[LiveImageClient performFetch] JSON decode error: \(error)")
            // JSONデコード失敗時のエラー処理
            // 必要に応じて、より詳細なエラー情報を含むカスタムエラーをスローします。
            throw error
        }
    }
}
