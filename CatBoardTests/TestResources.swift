import CBModel
import CoreGraphics
import Foundation
import UIKit

enum TestResources {
    static let mockURLs = [
        "test://image1",
        "test://image2",
        "test://image3",
        "test://image4",
        "test://image5",
        "test://image6",
        "test://image7",
        "test://image8",
        "test://image9",
        "test://image10",
    ]

    static func createMockCatImageURLModels(count: Int) -> [CatImageURLModel] {
        Array(mockURLs.prefix(count)).map { CatImageURLModel(imageURL: $0) }
    }

    static func createMockCatImageURLModels(using urls: [String]) -> [CatImageURLModel] {
        urls.map { CatImageURLModel(imageURL: $0) }
    }

    static func createMockJSONData(for urls: [String]) -> Data {
        let jsonString = """
        [
            \(urls.enumerated().map { index, url in
                """
                {
                    "id": "test\(index + 1)",
                    "url": "\(url)"
                }
                """
            }.joined(separator: ",\n"))
        ]
        """
        // swiftlint:disable:next force_unwrapping
        return jsonString.data(using: .utf8)!
    }

    static func createMockImageData() -> Data {
        let size = CGSize(width: 1, height: 1)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return image.jpegData(compressionQuality: 0.8) ?? Data()
    }
}
