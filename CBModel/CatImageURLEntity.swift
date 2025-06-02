import Foundation
import SwiftData

@Model
public final class CatImageURLEntity: @unchecked Sendable {
    @Attribute(.unique) public var id: UUID
    public var url: String
    public var createdAt: Date

    public init(url: String, createdAt: Date = .now) {
        id = UUID()
        self.url = url
        self.createdAt = createdAt
    }

    public convenience init(model: CatImageURLModel) {
        self.init(url: model.imageURL)
    }
}
