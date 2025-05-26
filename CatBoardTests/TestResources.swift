import CBModel
import CoreGraphics
import Foundation

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

    static func createMockCGImage() -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            fatalError("Failed to create CGContext for mock image")
        }

        guard let image = context.makeImage() else {
            fatalError("Failed to create mock CGImage")
        }
        return image
    }
}
