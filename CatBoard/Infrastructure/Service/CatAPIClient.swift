import ComposableArchitecture
import Foundation

// CatImageModel は他の場所（おそらく Model/）で定義されていると仮定
// struct CatImageModel: Codable, Identifiable { ... }

struct CatAPIClient {
    func fetchImages(limit: Int, page: Int) async throws -> [CatImageModel] {
        let apiUrl = "https://api.thecatapi.com/v1/images/search?limit=\(limit)&page=\(page)"

        guard let url = URL(string: apiUrl) else {
            // カスタムエラーの定義を検討
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse, (200 ... 299).contains(httpResponse.statusCode) else {
            // ステータスコードに基づいたカスタムエラーの定義を検討
            throw URLError(.badServerResponse)
        }

        do {
            // Ensure JSONDecoder is used correctly for the expected response structure
            let items = try JSONDecoder().decode([CatImageModel].self, from: data)
            return items
        } catch {
            // デバッグ用にデコードエラーをログに出力
            print("Decoding Error: \(error)")
            throw error // デコードエラーを再スロー
        }
    }
}
