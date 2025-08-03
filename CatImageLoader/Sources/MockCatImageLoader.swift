import Foundation

public actor MockCatImageLoader: CatImageLoaderProtocol {
    private var errorToThrow: Error?

    public var testImageURL: URL {
        let currentFileURL = URL(fileURLWithPath: #filePath)
        return currentFileURL
            .deletingLastPathComponent()
            .appendingPathComponent("SampleImage")
            .appendingPathComponent("SampleImage.jpg")
    }

    public init() {}

    /// エラーを設定する
    public func setError(_ error: Error?) {
        errorToThrow = error
    }

    public func loadImageData(from urls: [URL]) async throws -> [(
        imageData: Data,
        imageURL: URL
    )] {
        print("MockCatImageLoader.loadImageData が呼ばれました: \(urls.count)枚")

        // エラーが設定されている場合は投げてからクリア
        if let error = errorToThrow {
            print("MockCatImageLoader: エラーを投げます - \(error.localizedDescription)")
            errorToThrow = nil
            throw error
        }

        print("MockCatImageLoader: 正常処理を開始します")

        var loadedImages: [(imageData: Data, imageURL: URL)] = []
        loadedImages.reserveCapacity(urls.count)

        for (index, url) in urls.enumerated() {
            do {
                guard let imageData = try? Data(contentsOf: testImageURL) else {
                    throw NSError(
                        domain: "MockCatImageLoader",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Sample image not found"]
                    )
                }
                loadedImages.append((imageData: imageData, imageURL: url))
            } catch {
                print("画像のダウンロードに失敗 [\(index + 1)/\(urls.count)]: \(error.localizedDescription)")
                continue
            }
        }

        print("MockCatImageLoader: \(loadedImages.count)枚の画像を正常に読み込みました")
        return loadedImages
    }
}
