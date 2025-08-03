import Foundation
import SwiftData

@Model
public final class StoredCatImageURL: @unchecked Sendable {
    @Attribute(.unique) public let id: UUID
    public let imageURL: URL
    public let createdAt: Date

    init(imageURL: URL) {
        id = UUID()
        self.imageURL = imageURL
        createdAt = Date()
    }
}
