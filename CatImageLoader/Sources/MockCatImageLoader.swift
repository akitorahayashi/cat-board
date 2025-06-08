import CatAPIClient
import CatImageScreener
import CatURLImageModel
import Foundation

public struct MockCatImageLoader: CatImageLoaderProtocol {
    public var testImageURL: URL {
        let currentFileURL = URL(fileURLWithPath: #filePath)
        return currentFileURL
            .deletingLastPathComponent()
            .appendingPathComponent("SampleImage")
            .appendingPathComponent("cat__I3nlhPtP.jpg")
    }

    public init() {}

    public func loadImageData(from models: [CatImageURLModel]) async throws -> [(
        imageData: Data,
        model: CatImageURLModel
    )] {
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
