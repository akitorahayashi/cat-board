import CBShared
import ScaryCatScreeningKit
import UIKit

public struct LiveImageClient: ImageClientProtocol {
    public let enableScreening: Bool

    public init(enableScreening: Bool = true) {
        self.enableScreening = enableScreening
    }

    public func fetchImages(
        desiredSafeImageCountPerFetch: Int,
        timesOfFetch: Int
    ) async -> AsyncThrowingStream<[CatImageModel], Error> {
        AsyncThrowingStream { continuation in
            Task {
                var nextPageIndex = timesOfFetch
                // counter
                var totalFetchCount = 0
                var successfulDownloadCount = 0
                var safeScreenedImageCount = 0
                var yieldedSafeImageCount = 0

                print(
                    "[LiveImageClient Stream] 目標最大\(desiredSafeImageCountPerFetch)件の安全な画像取得を開始します。開始ページ: \(timesOfFetch)"
                )

                for attempt in 0 ..< timesOfFetch {
                    print(
                        "[LiveImageClient Stream] フェッチ試行 \(attempt + 1)/\(timesOfFetch), APIページ: \(nextPageIndex)"
                    )
                    totalFetchCount += 1

                    let fetchedImageModels: [CatImageModel]
                    do {
                        fetchedImageModels = try await performFetch(
                            imageCountPerRequest: desiredSafeImageCountPerFetch,
                            pageNumber: nextPageIndex
                        )
                    } catch {
                        print("[LiveImageClient Stream] performFetch でエラー: \(error)。ストリームを終了します。")
                        continuation.finish(throwing: error)
                        return
                    }

                    if fetchedImageModels.isEmpty {
                        print(
                            "[LiveImageClient Stream] APIページ \(nextPageIndex) から画像が取得できませんでした。これ以上のフェッチを中止し、ストリームを正常終了します。"
                        )
                        break
                    }

                    // 画像ダウンロード処理
                    let downloadResultsForBatch = await downloadImages(for: fetchedImageModels)

                    let successfulDownloadsForBatch = downloadResultsForBatch.compactMap { item -> (
                        model: CatImageModel,
                        image: UIImage
                    )? in
                        guard let image = item.image else { return nil }
                        return (item.model, image)
                    }
                    successfulDownloadCount += successfulDownloadsForBatch.count

                    if successfulDownloadsForBatch.isEmpty {
                        print("[LiveImageClient Stream] APIページ \(nextPageIndex) でダウンロード成功した画像がありませんでした。")
                        nextPageIndex += 1
                        continue
                    }

                    if !enableScreening {
                        let modelsToYield = successfulDownloadsForBatch.map(\.model)
                        if !modelsToYield.isEmpty {
                            print(
                                "[LiveImageClient Stream] スクリーニング無効のため、APIページ \(nextPageIndex) からダウンロード成功した \(modelsToYield.count)件の画像を Yield します。"
                            )
                            continuation.yield(modelsToYield)
                            yieldedSafeImageCount += modelsToYield.count
                        }
                        nextPageIndex += 1
                        continue
                    }

                    let imagesToScreenForBatch = successfulDownloadsForBatch.map(\.image)
                    let screener: OvRScaryCatScreener
                    do {
                        screener = try await OvRScaryCatScreener()
                    } catch let error as NSError {
                        print("[LiveImageClient Stream] OvRScaryCatScreener の初期化に失敗: \(error.localizedDescription)")
                        print("[LiveImageClient Stream] エラーコード: \(error.code), ドメイン: \(error.domain)")
                        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? Error {
                            print("[LiveImageClient Stream] 原因: \(underlying.localizedDescription)")
                        }
                        continuation.finish(throwing: error)
                        return
                    }

                    let screenedSafeImagesForBatch: [UIImage]
                    do {
                        screenedSafeImagesForBatch = try await screener.screen(
                            images: imagesToScreenForBatch,
                            probabilityThreshold: 0.85,
                            enableLogging: true
                        )
                    } catch let error as NSError {
                        print("[LiveImageClient Stream] スクリーニング処理でエラーが発生しました: \(error.localizedDescription)")
                        print("[LiveImageClient Stream] エラーコード: \(error.code), ドメイン: \(error.domain)")
                        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? Error {
                            print("[LiveImageClient Stream] 原因: \(underlying.localizedDescription)")
                        }
                        continuation.finish(throwing: error)
                        return
                    }
                    safeScreenedImageCount += screenedSafeImagesForBatch.count

                    if !screenedSafeImagesForBatch.isEmpty {
                        let newSafeModels = successfulDownloadsForBatch.filter {
                            screenedSafeImagesForBatch.contains($0.image)
                        }.map(\.model)

                        if !newSafeModels.isEmpty {
                            print(
                                "[LiveImageClient Stream] APIページ \(nextPageIndex) から \(newSafeModels.count)件の安全な画像を Yield します。"
                            )
                            continuation.yield(newSafeModels)
                            yieldedSafeImageCount += newSafeModels.count
                        } else {
                            print("[LiveImageClient Stream] APIページ \(nextPageIndex) のスクリーニング結果、安全な画像はありませんでした。")
                        }
                    } else {
                        print("[LiveImageClient Stream] APIページ \(nextPageIndex) のスクリーニング結果、安全な画像はありませんでした。")
                    }

                    nextPageIndex += 1
                }

                print("[LiveImageClient Stream] --- ストリーム処理結果レポート ---")
                print("[LiveImageClient Stream] APIフェッチ試行回数: \(totalFetchCount)回")
                print("[LiveImageClient Stream] ダウンロード成功総数: \(successfulDownloadCount)枚")
                if enableScreening {
                    print("[LiveImageClient Stream] スクリーニングで安全と判定された総数: \(safeScreenedImageCount)枚")
                }
                print("[LiveImageClient Stream] Yield した安全な画像の総数: \(yieldedSafeImageCount)件")
                print("[LiveImageClient Stream] ストリームを正常に終了します。")
                continuation.finish()
            }
        }
    }

    private func performFetch(imageCountPerRequest: Int, pageNumber: Int) async throws -> [CatImageModel] {
        guard let url =
            URL(
                string: "https://api.thecatapi.com/v1/images/search?limit=\(imageCountPerRequest)&page=\(pageNumber)&order=Rand"
            )
        else {
            throw URLError(.badURL)
        }

        let request = URLRequest(url: url)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            print("[LiveImageClient performFetch] HTTP Error: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            throw URLError(.badServerResponse)
        }

        do {
            let decoder = JSONDecoder()
            let catImages = try decoder.decode([CatImageModel].self, from: data)
            return catImages
        } catch {
            print("[LiveImageClient performFetch] JSON decode error: \(error)")
            throw error
        }
    }

    private func downloadImages(for models: [CatImageModel]) async -> [(model: CatImageModel, image: UIImage?)] {
        await withTaskGroup(of: (CatImageModel, UIImage?).self) { group in
            var results = [(CatImageModel, UIImage?)]()
            for model in models {
                group.addTask {
                    let session = URLSession(configuration: .ephemeral)
                    guard let url = URL(string: model.imageURL) else {
                        print("[LiveImageClient Stream] 不正なURL: \(model.imageURL) (ID: \(model.id))")
                        return (model, nil)
                    }
                    do {
                        let (data, _) = try await session.data(from: url)
                        return (model, UIImage(data: data))
                    } catch {
                        print(
                            "[LiveImageClient Stream] 画像ダウンロード失敗: \(model.id), URL: \(model.imageURL), Error: \(error)"
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
    }
}
