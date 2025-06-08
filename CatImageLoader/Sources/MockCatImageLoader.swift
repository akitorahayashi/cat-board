import CatAPIClient
import CatImageScreener
import CatURLImageModel
import Foundation

public actor MockCatImageLoader: CatImageLoaderProtocol {
    public var loadingTimePerOneImageInSeconds: Double = 0.01

    public var testImageURL: URL {
        let currentFileURL = URL(fileURLWithPath: #filePath)
        return currentFileURL
            .deletingLastPathComponent()
            .appendingPathComponent("SampleImage")
            .appendingPathComponent("cat__I3nlhPtP.jpg")
    }

    public init() {}

    public func setLoadingTimeInSeconds(_ time: Double) {
        loadingTimePerOneImageInSeconds = time
    }

    /// 指定した画像数の総ロード時間を計算する
    public func calculateTotalLoadingTime(for imageCount: Int) -> Double {
        Double(imageCount) * loadingTimePerOneImageInSeconds
    }

    public func loadImageData(from models: [CatImageURLModel]) async throws -> [(
        imageData: Data,
        model: CatImageURLModel
    )] {
        // ローディング時間のシミュレーション
        if loadingTimePerOneImageInSeconds > 0 {
            try await Task.sleep(nanoseconds: UInt64(loadingTimePerOneImageInSeconds * 1_000_000_000))
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
