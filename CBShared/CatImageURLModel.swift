import Foundation

public struct CatImageURLModel: Identifiable, Decodable, Equatable, Hashable {
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
public extension CatImageURLModel {
    init(entity: CatImageURLEntity) {
        id = UUID()
        imageURL = entity.url
        isLoading = false
    }
}
