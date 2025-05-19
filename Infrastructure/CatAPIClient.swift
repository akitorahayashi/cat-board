import CBShared
import ScaryCatScreeningKit
import UIKit

public struct CatAPIClient {
    public init() {}
    
    public func fetchImageURLs(totalCount: Int, batchSize: Int) async throws -> [CatImageURLModel] {
        print("CatAPIから画像URLの取得開始: 合計\(totalCount)枚")
        var result: [CatImageURLModel] = []

        for page in 0..<(Int(ceil(Double(totalCount) / Double(batchSize)))) {
            guard let url = URL(string: "https://api.thecatapi.com/v1/images/search?limit=\(batchSize)&page=\(page)&order=Rand") else {
                print("無効なURL")
                throw URLError(.badURL)
            }

            let request = URLRequest(url: url)
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("APIレスポンスエラー: \(response)")
                throw URLError(.badServerResponse)
            }

            let decoder = JSONDecoder()
            let catImages = try decoder.decode([CatImageURLModel].self, from: data)
            result += catImages

            if result.count >= totalCount { break }
        }

        print("画像URLの取得完了: \(result.count)枚")
        return Array(result.prefix(totalCount))
    }
}
