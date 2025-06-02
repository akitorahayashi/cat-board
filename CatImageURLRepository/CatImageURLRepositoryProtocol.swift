import CBModel

public protocol CatImageURLRepositoryProtocol: Sendable {
    func getNextImageURLs(count: Int) async throws -> [CatImageURLModel]
}