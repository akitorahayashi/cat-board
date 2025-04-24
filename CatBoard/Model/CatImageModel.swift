import Foundation

struct CatImageModel: Identifiable, Decodable, Equatable {
    var id = UUID()
    let imageURL: String
    enum CodingKeys: String, CodingKey {
        case imageURL = "url"
    }
}
