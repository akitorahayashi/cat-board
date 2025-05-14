import CBShared

public protocol ImageClientProtocol {
    func fetchImages(desiredSafeImageCountPerFetch: Int, timesOfFetch: Int) async
        -> AsyncThrowingStream<[CatImageModel], Error>
}
