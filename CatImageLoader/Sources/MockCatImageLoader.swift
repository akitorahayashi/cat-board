import CatAPIClient
import CatImageScreener
import CatURLImageModel
import Foundation

public actor MockCatImageLoader: CatImageLoaderProtocol {
    public var loadingTimeInSeconds: Double = 0.01

    public var testImageURL: URL {
        let currentFileURL = URL(fileURLWithPath: #filePath)
        return currentFileURL
            .deletingLastPathComponent()
            .appendingPathComponent("SampleImage")
            .appendingPathComponent("cat__I3nlhPtP.jpg")
    }

    public init() {}

    public func setLoadingTimeInSeconds(_ time: Double) {
        loadingTimeInSeconds = time
    }

    public func loadImageData(from models: [CatImageURLModel]) async throws -> [(
        imageData: Data,
        model: CatImageURLModel
    )] {
        // ローディング時間のシミュレーション
        if loadingTimeInSeconds > 0 {
            try await Task.sleep(nanoseconds: UInt64(loadingTimeInSeconds * 1_000_000_000))
        }

        var loadedImages: [(imageData: Data, model: CatImageURLModel)] = []
        loadedImages.reserveCapacity(models.count)

        for (index, model) in models.enumerated() {
            do {
                guard let imageData = try? Data(contentsOf: testImageURL) else {
                    throw NSError(
                        domain: "MockCatImageLoader",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Sample image not found"]
                    )
                }
                loadedImages.append((imageData: imageData, model: model))
            } catch {
                print("画像のダウンロードに失敗 [\(index + 1)/\(models.count)]: \(error.localizedDescription)")
                continue
            }
        }

        return loadedImages
    }
}
