import ComposableArchitecture
import Dependencies
import Infrastructure

public extension DependencyValues {
    var imageClient: ImageClientProtocol {
        get { self[ImageClientKey.self] }
        set { self[ImageClientKey.self] = newValue }
    }
}
