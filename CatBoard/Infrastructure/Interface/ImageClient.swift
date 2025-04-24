import ComposableArchitecture
import Foundation

struct ImageClient {
    var fetchImages: @Sendable (Int, Int) async throws -> [CatImageModel]
}

extension ImageClient: DependencyKey {
    static let liveValue = Self(
        fetchImages: { limit, page in
            try await CatAPIClient().fetchImages(limit: limit, page: page)
        }
    )

    static let previewValue: ImageClient = Self(
        fetchImages: { _, _ in
            print("Using preview ImageClient - Returning sample data")
            try await Task.sleep(for: .seconds(1))
            return []
        }
    )

    static let testValue: ImageClient = Self(
        fetchImages: unimplemented("\(Self.self).fetchImages")
    )
}

extension DependencyValues {
    var imageClient: ImageClient {
        get { self[ImageClient.self] }
        set { self[ImageClient.self] = newValue }
    }
}
