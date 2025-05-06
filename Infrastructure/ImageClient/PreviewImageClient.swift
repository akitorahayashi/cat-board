import CBShared

public struct PreviewImageClient: ImageClientProtocol {
    public var fetchImages: @Sendable (Int, Int) async throws -> [CatImageModel] {
        { _, _ in
            []
        }
    }

    public init() {}
}
