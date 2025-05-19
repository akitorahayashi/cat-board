import CBShared
import ScaryCatScreeningKit
import UIKit

public struct CatAPIClient: CatAPIClientProtocol {
    public func fetchImageURLs(imageConuntPerFetch imageCountPerFetch: Int, timesOfFetch: Int) async -> AsyncThrowingStream<[CatImageModel], Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    for page in 0..<timesOfFetch {
                        guard let url = URL(string: "https://api.thecatapi.com/v1/images/search?limit=\(imageCountPerFetch)&page=\(page)&order=Rand") else {
                            continuation.finish(throwing: URLError(.badURL))
                            return
                        }

                        let request = URLRequest(url: url)
                        let (data, response) = try await URLSession.shared.data(for: request)

                        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                            continuation.finish(throwing: URLError(.badServerResponse))
                            return
                        }

                        let decoder = JSONDecoder()
                        let catImages = try decoder.decode([CatImageModel].self, from: data)
                        continuation.yield(catImages)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
