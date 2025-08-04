import Foundation

public struct CatAPIClient: CatAPIClientProtocol {
    public init() {}

    private struct CatAPIResponse: Decodable {
        let url: String
    }

    public func fetchImageURLs(totalCount: Int, batchSize: Int = 10) async throws -> [URL] {
        var result: [URL] = []
        var pagesRetrieved = 0

        for page in 0 ..< Int(ceil(Double(totalCount) / Double(batchSize))) {
            guard let url =
                URL(string: "https://api.thecatapi.com/v1/images/search?limit=\(batchSize)&page=\(page)&order=Rand")
            else {
                throw URLError(.badURL)
            }

            let request = URLRequest(url: url)
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }

            let decoder = JSONDecoder()
            let catImages = try decoder.decode([CatAPIResponse].self, from: data)
            result += catImages.compactMap { URL(string: $0.url) }
            pagesRetrieved += 1

            if result.count >= totalCount { break }
        }

        return Array(result.prefix(totalCount))
    }
}
