import CatURLImageModel
import Foundation
import Kingfisher

#if os(iOS)
    private func toJPEGData(_ image: KFCrossPlatformImage, _ quality: CGFloat) -> Data? {
        image.jpegData(compressionQuality: quality)
    }

#elseif os(macOS)
    import AppKit

    private func toJPEGData(_ image: KFCrossPlatformImage, _ quality: CGFloat) -> Data? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: quality])
    }
#endif

public actor CatImageLoader: CatImageLoaderProtocol {
    public init() {
        // Kingfisherのキャッシュを設定
        let diskCache = KingfisherManager.shared.cache.diskStorage

        // メモリキャッシュの制限: 200MB
        let memoryCache = KingfisherManager.shared.cache.memoryStorage
        memoryCache.config.totalCostLimit = 200 * 1024 * 1024

        // ディスクキャッシュの制限: 500MB
        diskCache.config.sizeLimit = 500 * 1024 * 1024
        diskCache.config.expiration = .days(3) // 3日間保持
    }

    deinit {
        KingfisherManager.shared.cache.clearMemoryCache()
    }

    public nonisolated func loadImageData(from models: [CatImageURLModel]) async throws -> [(
        imageData: Data,
        model: CatImageURLModel
    )] {
        var loadedImages: [(imageData: Data, model: CatImageURLModel)] = []
        loadedImages.reserveCapacity(models.count)

        for (index, item) in models.enumerated() {
            guard let url = URL(string: item.imageURL) else {
                print("無効なURL: \(item.imageURL)")
                continue
            }

            do {
                let result = try await KingfisherManager.shared.retrieveImage(
                    with: url,
                    options: [
                        .requestModifier(AnyModifier { request in
                            var r = request
                            r.timeoutInterval = 10
                            return r
                        }),
                        .diskCacheExpiration(.days(3)),
                    ]
                )

                autoreleasepool {
                    if let imageData = toJPEGData(result.image, 0.8) {
                        loadedImages.append((imageData: imageData, model: item))
                    }
                }
            } catch let error as NSError {
                if error.domain == NSURLErrorDomain, error.code == NSURLErrorNotConnectedToInternet {
                    throw error
                }
                let errorType = error.domain == NSURLErrorDomain ? "ネットワーク" : "その他"
                print("画像のダウンロードに失敗 [\(index + 1)/\(models.count)]: \(errorType)エラー (\(item.imageURL))")
                continue
            }
        }
        return loadedImages
    }
}
