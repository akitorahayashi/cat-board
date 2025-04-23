import Foundation

// BlockModelから名前変更し、Decodableに準拠
struct ImageItem: Identifiable, Decodable {
    var id = UUID()
    let imageURL: String
    enum CodingKeys: String, CodingKey {
        case imageURL = "url" // JSONの"url"キーをimageURLプロパティにマッピング
    }
}
