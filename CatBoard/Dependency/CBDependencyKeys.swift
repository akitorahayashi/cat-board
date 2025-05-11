import CBShared
import ComposableArchitecture
import Infrastructure

enum ImageClientKey: DependencyKey {
    static let liveValue: ImageClientProtocol = LiveImageClient()
    #if DEBUG
        static let previewValue: ImageClientProtocol = PreviewImageClient()
        static let testValue: ImageClientProtocol = MockImageClient()
    #else
        // Releaseビルド時は Test/Preview に Live を使う
        static let previewValue: ImageClientProtocol = LiveImageClient()
        static let testValue: ImageClientProtocol = LiveImageClient()
    #endif
}
