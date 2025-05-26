import CBModel
import Foundation

public final class MockCatAPIClient: CatAPIClientProtocol {
    private let mockURLs = [
        "https://cdn2.thecatapi.com/images/MTY3ODIyMQ.jpg",
        "https://cdn2.thecatapi.com/images/1j6.jpg",
        "https://cdn2.thecatapi.com/images/2j6.jpg",
        "https://cdn2.thecatapi.com/images/3j6.jpg",
        "https://cdn2.thecatapi.com/images/4j6.jpg",
        "https://cdn2.thecatapi.com/images/5j6.jpg",
        "https://cdn2.thecatapi.com/images/6j6.jpg",
        "https://cdn2.thecatapi.com/images/7j6.jpg",
        "https://cdn2.thecatapi.com/images/8j6.jpg",
        "https://cdn2.thecatapi.com/images/9j6.jpg"
    ]
    
    public var fetchImageURLsError: Error?
    
    public init() {}
    
    public func fetchImageURLs(totalCount: Int, batchSize: Int) async throws -> [CatImageURLModel] {
        if let error = fetchImageURLsError {
            throw error
        }
        
        var result: [CatImageURLModel] = []
        for _ in 0..<totalCount {
            let randomURL = mockURLs.randomElement() ?? mockURLs[0]
            result.append(CatImageURLModel(imageURL: randomURL))
        }
        
        return result
    }
} 