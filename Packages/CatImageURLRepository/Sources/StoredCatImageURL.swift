import Foundation
import SwiftData

@Model
public final class StoredCatImageURL: @unchecked Sendable {
    @Attribute(.unique) public var id: UUID
    public var imageURL: URL
    public var createdAt: Date

    init(imageURL: URL) {
        id = UUID()
        self.imageURL = imageURL
        createdAt = Date()
    }
}
