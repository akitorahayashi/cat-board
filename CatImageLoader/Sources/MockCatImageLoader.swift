import CatAPIClient
import CatImageScreener
import CatURLImageModel
import Foundation

public actor MockCatImageLoader: CatImageLoaderProtocol {
    public var loadingTimePerOneImageInSeconds: Double = 0.01
    private var errorToThrow: Error?

    public var testImageURL: URL {
        let currentFileURL = URL(fileURLWithPath: #filePath)
        return currentFileURL
            .deletingLastPathComponent()
            .appendingPathComponent("SampleImage")
            .appendingPathComponent("cat_1be.jpg")
    }

    public init() {}

    /// エラーを設定する
    public func setError(_ error: Error?) {
        errorToThrow = error
    }

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
        print("MockCatImageLoader.loadImageData が呼ばれました: \(models.count)枚")

        // エラーが設定されている場合は投げてからクリア
        if let error = errorToThrow {
            print("MockCatImageLoader: エラーを投げます - \(error.localizedDescription)")
            errorToThrow = nil
            throw error
        }

        print("MockCatImageLoader: 正常処理を開始します")

        var loadedImages: [(imageData: Data, model: CatImageURLModel)] = []
        loadedImages.reserveCapacity(models.count)

        for (index, model) in models.enumerated() {
            // 各画像に対してローディング時間をシミュレーション
            if loadingTimePerOneImageInSeconds > 0 {
                try await Task.sleep(nanoseconds: UInt64(loadingTimePerOneImageInSeconds * 1_000_000_000))
            }

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

        print("MockCatImageLoader: \(loadedImages.count)枚の画像を正常に読み込みました")
        return loadedImages
    }
}
