import CBShared

public struct PreviewImageClient: ImageClientProtocol {
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
                let dummyImageURL = "https://via.placeholder.com/150"

                let dummyModelsBatch1 = [
                    CatImageModel(imageURL: dummyImageURL),
                    CatImageModel(imageURL: dummyImageURL),
                ]
                continuation.yield(dummyModelsBatch1)

                if desiredSafeImageCountPerFetch > 2 {
                    try? await Task.sleep(for: .milliseconds(300))

                    let dummyModelsBatch2 = [
                        CatImageModel(imageURL: dummyImageURL),
                    ]
                    continuation.yield(dummyModelsBatch2)
                }

                continuation.finish()
            }
        }
    }
}
