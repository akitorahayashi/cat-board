import CatScreeningKit
import CBShared
import ComposableArchitecture
import UIKit

public struct LiveImageClient: ImageClientProtocol {
    public init() {}

    public var fetchImages: @Sendable (Int, Int) async throws -> [CatImageModel] {
        // requestedLimit: 最終的に取得したい安全な画像の目標枚数 (例: 10)
        // initialPage: 内部でAPIを叩き始める際の開始ページ番号
        { requestedLimit, initialPage in
            var accumulatedSafeModels: [CatImageModel] = []
            var currentPage = initialPage
            let imagesToFetchPerAttempt = 10 // 1回のAPI呼び出しで取得を試みる画像数
            let maxFetchAttempts = 5       // API呼び出しの最大試行回数 (無限ループ防止)
            var actualFetchAttempts = 0    // 実際に performFetch を呼び出した回数
            var totalDownloadedImagesCount = 0 // ダウンロードに成功した総画像数
            var totalScreenedSafeImagesCount = 0 // スクリーニングで安全と判定された総画像数

            print("[LiveImageClient] 目標\(requestedLimit)件の安全な画像取得を開始します。開始ページ: \(initialPage)")

            for attempt in 0..<maxFetchAttempts {
                if accumulatedSafeModels.count >= requestedLimit {
                    print("[LiveImageClient] 既に目標数の安全な画像 (\(accumulatedSafeModels.count)件) を取得済みのため、フェッチを終了します。")
                    break
                }

                print("[LiveImageClient] フェッチ試行 \(attempt + 1)/\(maxFetchAttempts), APIページ: \(currentPage)")
                actualFetchAttempts += 1
                let fetchedImageModels = try await self.performFetch(limit: imagesToFetchPerAttempt, page: currentPage)

                if fetchedImageModels.isEmpty {
                    print("[LiveImageClient] APIページ \(currentPage) から画像が取得できませんでした。これ以上のフェッチを中止します。")
                    break // これ以上APIから画像が取れない
                }

                // 画像ダウンロード処理 (現在のバッチに対して)
                let downloadResultsForBatch: [(model: CatImageModel, image: UIImage?)] = await withTaskGroup(of: (CatImageModel, UIImage?).self) { group in
                    var results = [(CatImageModel, UIImage?)]()
                    for model in fetchedImageModels {
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
                                print("[LiveImageClient] 画像ダウンロード失敗: \(model.id), URL: \(model.imageURL), Error: \(error)")
                                return (model, nil)
                            }
                        }
                    }
                    for await result in group {
                        results.append(result)
                    }
                    return results
                }

                let successfulDownloadsForBatch = downloadResultsForBatch.compactMap { item -> (model: CatImageModel, image: UIImage)? in
                    guard let image = item.image else { return nil }
                    return (item.model, image)
                }
                totalDownloadedImagesCount += successfulDownloadsForBatch.count

                if successfulDownloadsForBatch.isEmpty {
                    print("[LiveImageClient] APIページ \(currentPage) でダウンロード成功した画像がありませんでした。")
                    currentPage += 1
                    continue // 次のフェッチ試行へ
                }

                // 画像スクリーニング処理 (現在のバッチに対して)
                let imagesToScreenForBatch = successfulDownloadsForBatch.map(\.image)
                let screener = try ScaryCatScreener() // 注意: ループ毎に初期化。必要なら外部で一度だけ初期化を検討。
                let screenedSafeImagesForBatch: [UIImage] = try await screener.screen(images: imagesToScreenForBatch, enableLogging: true)
                totalScreenedSafeImagesCount += screenedSafeImagesForBatch.count

                if !screenedSafeImagesForBatch.isEmpty {
                    let newSafeModels = successfulDownloadsForBatch.filter {
                        screenedSafeImagesForBatch.contains($0.image) // $0.image は UIImage なので UIImage の配列と比較
                    }.map { $0.model }
                    
                    if !newSafeModels.isEmpty {
                        print("[LiveImageClient] APIページ \(currentPage) から \(newSafeModels.count)件の安全な画像が見つかりました。")
                        accumulatedSafeModels.append(contentsOf: newSafeModels)
                    } else {
                        print("[LiveImageClient] APIページ \(currentPage) のスクリーニング結果、安全な画像はありませんでした。")
                    }
                } else {
                    print("[LiveImageClient] APIページ \(currentPage) のスクリーニング結果、安全な画像はありませんでした。")
                }
                
                currentPage += 1
            }

            // 最終的に蓄積されたモデルリストを要求数に切り詰める
            let finalModels = Array(accumulatedSafeModels.prefix(requestedLimit))
            let totalRejectedImagesCount = totalDownloadedImagesCount - totalScreenedSafeImagesCount
            print("[LiveImageClient] --- 処理結果レポート ---")
            print("[LiveImageClient] APIフェッチ試行回数: \(actualFetchAttempts)回")
            print("[LiveImageClient] ダウンロード成功総数: \(totalDownloadedImagesCount)枚")
            print("[LiveImageClient] スクリーニングで安全と判定された総数: \(totalScreenedSafeImagesCount)枚")
            print("[LiveImageClient] スクリーニングで除外された総数: \(totalRejectedImagesCount)枚")
            print("[LiveImageClient] 最終的に \(finalModels.count)件の安全な画像を返します。 (要求数: \(requestedLimit)) ")
            return finalModels
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
