import Foundation
import SwiftData

@Model
public class CatImageURLEntity {
    @Attribute(.unique) public var id: UUID
    public var url: String
    public var createdAt: Date

    public init(url: String, createdAt: Date = .now) {
        self.id = UUID()
        self.url = url
        self.createdAt = createdAt
    }

    public convenience init(model: CatImageURLModel) {
        self.init(url: model.imageURL)
    }
}
