import CBShared

public struct MockImageClient: ImageClientProtocol {
    public var fetchImages: @Sendable (Int, Int) async throws -> [CatImageModel] {
        { _, _ in
            try? await Task.sleep(nanoseconds: 500_000_000)
            return []
        }
    }

    public init() {}
}
