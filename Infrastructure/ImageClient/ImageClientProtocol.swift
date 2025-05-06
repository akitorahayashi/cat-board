import CBShared

public protocol ImageClientProtocol {
    var fetchImages: @Sendable (Int, Int) async throws -> [CatImageModel] { get }
}
