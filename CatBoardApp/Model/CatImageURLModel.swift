import CatImagePrefetcher
import CatImageURLRepository
import Foundation

public struct CatImageURLModel: Identifiable, Decodable, Equatable, Hashable, Sendable {
    public let id: UUID
    public let imageURL: URL
    private enum CodingKeys: String, CodingKey {
        case imageURL = "url"
    }

    public init(imageURL: URL) {
        id = UUID()
        self.imageURL = imageURL
    }

    // StoredCatImageURL からの変換用
    public init(entity: StoredCatImageURL) {
        id = entity.id
        imageURL = entity.imageURL
    }

    // PrefetchedCatImageURL からの変換用
    public init(prefetched: PrefetchedCatImageURL) {
        id = prefetched.id
        imageURL = prefetched.imageURL
    }

    // Decodable の実装
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = UUID()
        imageURL = try container.decode(URL.self, forKey: .imageURL)
    }
}
