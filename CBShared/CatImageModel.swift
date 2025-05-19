import Foundation

public struct CatImageModel: Identifiable, Decodable, Equatable, Hashable {
    public var id = UUID()
    public var imageURL: String
    public var isLoading: Bool = true
    enum CodingKeys: String, CodingKey {
        case imageURL = "url"
    }

    public init(id: UUID = UUID(), imageURL: String, isLoading: Bool = true) {
        self.id = id
        self.imageURL = imageURL
        self.isLoading = isLoading
    }
}

// SwiftData の CatImageEntity からの変換用
public extension CatImageModel {
    init(entity: CatImageEntity) {
        self.id = UUID()
        self.imageURL = entity.url
        self.isLoading = false
    }
}
