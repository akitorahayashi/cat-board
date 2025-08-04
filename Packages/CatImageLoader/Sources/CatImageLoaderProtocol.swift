import Foundation

public protocol CatImageLoaderProtocol: Sendable {
    /// 指定された画像URLオブジェクトから Data を取得する
    func loadImageData(from urls: [URL]) async throws -> [(imageData: Data, imageURL: URL)]
}
