import CBShared
import ComposableArchitecture // AsyncThrowingStream を使うために必要になる可能性

public protocol ImageClientProtocol {
    func fetchImages(desiredSafeImageCountPerFetch: Int, timesOfFetch: Int) async -> AsyncThrowingStream<[CatImageModel], Error>
}
