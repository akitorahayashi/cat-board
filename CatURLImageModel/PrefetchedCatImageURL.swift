import Foundation
import SwiftData

@Model
public final class PrefetchedCatImageURL: @unchecked Sendable {
    @Attribute(.unique) public var id: UUID
    public var imageURL: String
    public var createdAt: Date

    public init(model: CatImageURLModel) {
        id = UUID()
        imageURL = model.imageURL
        createdAt = Date()
    }
}
