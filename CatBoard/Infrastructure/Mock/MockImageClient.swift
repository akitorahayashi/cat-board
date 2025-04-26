import ComposableArchitecture
import Foundation

extension ImageClient {
    static let mockValue: ImageClient = Self(
        fetchImages: { _, _ in
            print("Using mock ImageClient - Returning sample data")
            // Simulate network delay
            try await Task.sleep(for: .milliseconds(500))
            // 猫のサンプル
            // CatImageModel(imageURL: "https://cdn2.thecatapi.com/images/b9b.jpg"),
            // 怖い画像
            // CatImageModel(imageURL: "https://cdn2.thecatapi.com/images/MTY3ODIyMQ.jpg"),
            return [
                CatImageModel(imageURL: "https://cdn2.thecatapi.com/images/b9b.jpg"),
                CatImageModel(imageURL: "https://cdn2.thecatapi.com/images/b9b.jpg"),
                CatImageModel(imageURL: "https://cdn2.thecatapi.com/images/b9b.jpg"),
//                CatImageModel(imageURL: "https://cdn2.thecatapi.com/images/b9b.jpg"),
//                CatImageModel(imageURL: "https://cdn2.thecatapi.com/images/b9b.jpg"),
//                CatImageModel(imageURL: "https://cdn2.thecatapi.com/images/b9b.jpg"),
//                CatImageModel(imageURL: "https://cdn2.thecatapi.com/images/b9b.jpg"),
//                CatImageModel(imageURL: "https://cdn2.thecatapi.com/images/b9b.jpg"),
//                CatImageModel(imageURL: "https://cdn2.thecatapi.com/images/b9b.jpg"),
//                CatImageModel(imageURL: "https://cdn2.thecatapi.com/images/b9b.jpg"),
//                CatImageModel(imageURL: "https://cdn2.thecatapi.com/images/b9b.jpg"),
//                CatImageModel(imageURL: "https://cdn2.thecatapi.com/images/b9b.jpg"),
//                CatImageModel(imageURL: "https://cdn2.thecatapi.com/images/b9b.jpg"),
//                CatImageModel(imageURL: "https://cdn2.thecatapi.com/images/b9b.jpg"),
//                CatImageModel(imageURL: "https://cdn2.thecatapi.com/images/b9b.jpg"),
//                CatImageModel(imageURL: "https://cdn2.thecatapi.com/images/b9b.jpg"),
//                CatImageModel(imageURL: "https://cdn2.thecatapi.com/images/b9b.jpg"),
//                CatImageModel(imageURL: "https://cdn2.thecatapi.com/images/b9b.jpg"),
//                CatImageModel(imageURL: "https://cdn2.thecatapi.com/images/b9b.jpg"),
//                CatImageModel(imageURL: "https://cdn2.thecatapi.com/images/b9b.jpg"),
//                CatImageModel(imageURL: "https://cdn2.thecatapi.com/images/b9b.jpg"),
//                CatImageModel(imageURL: "https://cdn2.thecatapi.com/images/b9b.jpg"),
//                CatImageModel(imageURL: "https://cdn2.thecatapi.com/images/b9b.jpg"),
//                CatImageModel(imageURL: "https://cdn2.thecatapi.com/images/b9b.jpg"),
//                CatImageModel(imageURL: "https://cdn2.thecatapi.com/images/b9b.jpg"),
//                CatImageModel(imageURL: "https://cdn2.thecatapi.com/images/b9b.jpg"),
//                CatImageModel(imageURL: "https://cdn2.thecatapi.com/images/b9b.jpg"),
//                CatImageModel(imageURL: "https://cdn2.thecatapi.com/images/b9b.jpg"),
//                CatImageModel(imageURL: "https://cdn2.thecatapi.com/images/b9b.jpg"),
//                CatImageModel(imageURL: "https://cdn2.thecatapi.com/images/b9b.jpg"),
//                CatImageModel(imageURL: "https://cdn2.thecatapi.com/images/b9b.jpg"),
//                CatImageModel(imageURL: "https://cdn2.thecatapi.com/images/b9b.jpg"),
//                CatImageModel(imageURL: "https://cdn2.thecatapi.com/images/b9b.jpg"),
//                CatImageModel(imageURL: "https://cdn2.thecatapi.com/images/b9b.jpg"),
            ]
            
        }
    )
}
