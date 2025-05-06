import CatScreeningKit
import CBShared
import ComposableArchitecture
import UIKit

public struct LiveImageClient: ImageClientProtocol {
    public init() {}

    // requestedLimit: 最終的に取得したい安全な画像の目標枚数 (今回はストリームの早期終了には直接使用しないが、呼び出し側が利用する可能性あり)
    // initialPage: 内部でAPIを叩き始める際の開始ページ番号
    public var fetchImages: @Sendable (Int, Int) async -> AsyncThrowingStream<[CatImageModel], Error> {
        { requestedLimit, initialPage in
            AsyncThrowingStream { continuation in
                Task {
                    var currentPage = initialPage
                    let imagesToFetchPerAttempt = 10 // 1回のAPI呼び出しで取得を試みる画像数
                    let maxFetchAttempts = 5       // API呼び出しの最大試行回数 (無限ループ防止)
                    var actualFetchAttempts = 0    // 実際に performFetch を呼び出した回数
                    var totalDownloadedImagesCount = 0 // ダウンロードに成功した総画像数
                    var totalScreenedSafeImagesCount = 0 // スクリーニングで安全と判定された総画像数
                    var yieldedSafeModelsCount = 0 // ストリームにyieldした安全な画像の総数

                    print("[LiveImageClient Stream] 目標最大\(requestedLimit)件の安全な画像取得を開始します。開始ページ: \(initialPage)")

                    do {
                        for attempt in 0..<maxFetchAttempts {
                            // ストリームの呼び出し側が requestedLimit を見て終了する場合もあるので、
                            // ここでは requestedLimit に基づく早期終了は行わない。
                            // もしストリーム自体が一定数で終了したい場合は、ここで yieldedSafeModelsCount >= requestedLimit で break も可能。

                            print("[LiveImageClient Stream] フェッチ試行 \(attempt + 1)/\(maxFetchAttempts), APIページ: \(currentPage)")
                            actualFetchAttempts += 1
                            
                            let fetchedImageModels: [CatImageModel]
                            do {
                                fetchedImageModels = try await self.performFetch(limit: imagesToFetchPerAttempt, page: currentPage)
                            } catch {
                                print("[LiveImageClient Stream] performFetch でエラー: \(error)。ストリームを終了します。")
                                continuation.finish(throwing: error)
                                return
                            }

                            if fetchedImageModels.isEmpty {
                                print("[LiveImageClient Stream] APIページ \(currentPage) から画像が取得できませんでした。これ以上のフェッチを中止し、ストリームを正常終了します。")
                                break // これ以上APIから画像が取れないのでループを抜ける
                            }

                            // 画像ダウンロード処理 (現在のバッチに対して)
                            let downloadResultsForBatch: [(model: CatImageModel, image: UIImage?)] = await withTaskGroup(of: (CatImageModel, UIImage?).self) { group in
                                var results = [(CatImageModel, UIImage?)]()
                                for model in fetchedImageModels {
                                    group.addTask {
                                        let session = URLSession(configuration: .ephemeral) // Consider reusing session
                                        guard let url = URL(string: model.imageURL) else {
                                            print("[LiveImageClient Stream] 不正なURL: \(model.imageURL) (ID: \(model.id))")
                                            return (model, nil)
                                        }
                                        do {
                                            let (data, _) = try await session.data(from: url)
                                            return (model, UIImage(data: data))
                                        } catch {
                                            print("[LiveImageClient Stream] 画像ダウンロード失敗: \(model.id), URL: \(model.imageURL), Error: \(error)")
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
                                print("[LiveImageClient Stream] APIページ \(currentPage) でダウンロード成功した画像がありませんでした。")
                                currentPage += 1
                                continue // 次のフェッチ試行へ
                            }

                            // 画像スクリーニング処理 (現在のバッチに対して)
                            let imagesToScreenForBatch = successfulDownloadsForBatch.map(\.image)
                            let screener: ScaryCatScreener
                            do {
                                screener = try ScaryCatScreener() // 注意: ループ毎に初期化。
                            } catch {
                                print("[LiveImageClient Stream] ScaryCatScreener の初期化に失敗: \(error)。ストリームを終了します。")
                                continuation.finish(throwing: error)
                                return
                            }
                            
                            let screenedSafeImagesForBatch: [UIImage]
                            do {
                                screenedSafeImagesForBatch = try await screener.screen(images: imagesToScreenForBatch, enableLogging: true)
                            } catch {
                                print("[LiveImageClient Stream] スクリーニング処理でエラー: \(error)。ストリームを終了します。")
                                continuation.finish(throwing: error)
                                return
                            }
                            totalScreenedSafeImagesCount += screenedSafeImagesForBatch.count

                            if !screenedSafeImagesForBatch.isEmpty {
                                let newSafeModels = successfulDownloadsForBatch.filter {
                                    screenedSafeImagesForBatch.contains($0.image)
                                }.map { $0.model }
                                
                                if !newSafeModels.isEmpty {
                                    print("[LiveImageClient Stream] APIページ \(currentPage) から \(newSafeModels.count)件の安全な画像を Yield します。")
                                    continuation.yield(newSafeModels)
                                    yieldedSafeModelsCount += newSafeModels.count
                                } else {
                                    print("[LiveImageClient Stream] APIページ \(currentPage) のスクリーニング結果、安全な画像はありませんでした。")
                                }
                            } else {
                                print("[LiveImageClient Stream] APIページ \(currentPage) のスクリーニング結果、安全な画像はありませんでした。")
                            }
                            
                            currentPage += 1
                        }

                        // ループが正常に終了した場合 (maxFetchAttempts に達したか、APIから画像が取れなくなった)
                        print("[LiveImageClient Stream] --- ストリーム処理結果レポート ---")
                        print("[LiveImageClient Stream] APIフェッチ試行回数: \(actualFetchAttempts)回")
                        print("[LiveImageClient Stream] ダウンロード成功総数: \(totalDownloadedImagesCount)枚")
                        print("[LiveImageClient Stream] スクリーニングで安全と判定された総数: \(totalScreenedSafeImagesCount)枚")
                        print("[LiveImageClient Stream] Yield した安全な画像の総数: \(yieldedSafeModelsCount)件")
                        print("[LiveImageClient Stream] ストリームを正常に終了します。")
                        continuation.finish()

                    } catch { // Task 内の予期せぬエラー
                        print("[LiveImageClient Stream] 予期せぬエラーが発生しました: \(error)。ストリームを終了します。")
                        continuation.finish(throwing: error)
                    }
                }
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
