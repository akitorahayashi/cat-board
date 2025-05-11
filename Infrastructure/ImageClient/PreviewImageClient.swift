import CBShared
import ComposableArchitecture // AsyncThrowingStream のために (標準ライブラリなので不要かも)

public struct PreviewImageClient: ImageClientProtocol {
    public var fetchImages: @Sendable (Int, Int) async -> AsyncThrowingStream<[CatImageModel], Error> {
        { requestedLimit, _ in // initialPage はプレビューでは無視
            AsyncThrowingStream { continuation in
                Task {
                    let dummyImageURL = "https://via.placeholder.com/150"

                    let dummyModelsBatch1 = [
                        CatImageModel(imageURL: dummyImageURL),
                        CatImageModel(imageURL: dummyImageURL),
                    ]
                    continuation.yield(dummyModelsBatch1)

                    if requestedLimit > 2 {
                        try? await Task.sleep(for: .milliseconds(300))

                        let dummyModelsBatch2 = [
                            CatImageModel(imageURL: dummyImageURL),
                        ]
                        if requestedLimit > 2 {
                            continuation.yield(dummyModelsBatch2)
                        }
                    }

                    continuation.finish()
                }
            }
        }
    }

    public init() {}
}
