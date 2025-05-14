import CBShared
import Foundation

public struct MockImageClient: ImageClientProtocol {
    public let enableScreening: Bool

    public init(enableScreening: Bool = true) {
        self.enableScreening = enableScreening
    }

    public func fetchImages(
        desiredSafeImageCountPerFetch: Int,
        timesOfFetch _: Int
    ) async -> AsyncThrowingStream<[CatImageModel], Error> {
        AsyncThrowingStream { continuation in
            Task {
                let dummyImageURL = "https://via.placeholder.com/120"
                try? await Task.sleep(for: .milliseconds(300))

                if desiredSafeImageCountPerFetch > 0 {
                    let mockData = [
                        CatImageModel(id: UUID(), imageURL: dummyImageURL),
                        CatImageModel(id: UUID(), imageURL: dummyImageURL),
                        CatImageModel(id: UUID(), imageURL: dummyImageURL),
                        CatImageModel(id: UUID(), imageURL: dummyImageURL),
                        CatImageModel(id: UUID(), imageURL: dummyImageURL),
                        CatImageModel(id: UUID(), imageURL: dummyImageURL),
                        CatImageModel(id: UUID(), imageURL: dummyImageURL),
                    ]
                    let dataToYield = Array(mockData.prefix(min(mockData.count, desiredSafeImageCountPerFetch)))
                    if !dataToYield.isEmpty {
                        continuation.yield(dataToYield)
                    }
                }

                continuation.finish()
            }
        }
    }
}
