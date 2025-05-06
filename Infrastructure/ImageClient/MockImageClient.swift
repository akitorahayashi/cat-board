import CBShared
import ComposableArchitecture
import Foundation

public struct MockImageClient: ImageClientProtocol {
    public var fetchImages: @Sendable (Int, Int) async -> AsyncThrowingStream<[CatImageModel], Error> {
        { requestedLimit, _ in
            AsyncThrowingStream { continuation in
                Task {
                    try? await Task.sleep(for: .milliseconds(300))

                    if requestedLimit > 0 {
                        let mockData = [
                            CatImageModel(id: UUID(), imageURL: "https://via.placeholder.com/120"),
                            CatImageModel(id: UUID(), imageURL: "https://via.placeholder.com/120"),
                            CatImageModel(id: UUID(), imageURL: "https://via.placeholder.com/120")
                        ]
                        let dataToYield = Array(mockData.prefix(min(mockData.count, requestedLimit)))
                        if !dataToYield.isEmpty {
                            continuation.yield(dataToYield)
                        }
                    }
                    
                    continuation.finish()
                }
            }
        }
    }

    public init() {}
}
