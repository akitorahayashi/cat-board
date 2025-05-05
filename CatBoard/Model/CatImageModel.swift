import Foundation

struct CatImageModel: Identifiable, Decodable, Equatable {
    var id = UUID()
    let imageURL: String
    var isLoading: Bool = true
    enum CodingKeys: String, CodingKey {
        case imageURL = "url"
    }
}
