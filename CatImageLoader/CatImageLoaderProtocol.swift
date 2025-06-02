import CBModel
import Foundation

public protocol CatImageLoaderProtocol: Sendable {
    /// 指定された画像URLモデルから画像を取得する
    func loadImageData(from models: [CatImageURLModel]) async throws -> [(imageData: Data, model: CatImageURLModel)]
}
