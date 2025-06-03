import Foundation
import SwiftData

public struct CatImageURLModel: Identifiable, Decodable, Equatable, Hashable, Sendable {
    public var id: UUID
    public var imageURL: String
    enum CodingKeys: String, CodingKey {
        case imageURL = "url"
    }

    public init(imageURL: String) {
        self.id = UUID()
        self.imageURL = imageURL
    }
    
    // StoredCatImageURL からの変換用
    public init(entity: StoredCatImageURL) {
        self.id = entity.id
        self.imageURL = entity.imageURL
    }
    
    // PrefetchedCatImageURL からの変換用
    public init(prefetched: PrefetchedCatImageURL) {
        self.id = prefetched.id
        self.imageURL = prefetched.imageURL
    }
    
    // Decodable の実装
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.imageURL = try container.decode(String.self, forKey: .imageURL)
    }
}
