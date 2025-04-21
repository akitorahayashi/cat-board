import SwiftUI

@MainActor
class ContentViewModel: ObservableObject {
    @Published var items: [ImageItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil

    func fetchImages() async {
        isLoading = true
        errorMessage = nil

        // Cat API のエンドポイント
        let apiUrl = "https://api.thecatapi.com/v1/images/search?limit=20"

        guard let url = URL(string: apiUrl) else {
            errorMessage = "Invalid API URL"
            isLoading = false
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                errorMessage = "API Error: Status code \(httpResponse.statusCode)"
                isLoading = false
                return // エラーを検知した後に終了
            }

            // JSON配列を直接[ImageItem]にデコード
            items = try JSONDecoder().decode([ImageItem].self, from: data)
        } catch {
            errorMessage = "データの取得またはデコード中にエラーが発生しました: \(error.localizedDescription)"
            print("エラー詳細: \(error)")
        }

        isLoading = false
    }
}
