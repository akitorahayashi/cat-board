import CBShared
import ComposableArchitecture // AsyncThrowingStream を使うために必要になる可能性

public protocol ImageClientProtocol {
    var fetchImages: @Sendable (Int, Int) async -> AsyncThrowingStream<[CatImageModel], Error> { get }
}
