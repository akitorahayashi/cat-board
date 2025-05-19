import CBShared

public protocol CatAPIClientProtocol {
    func fetchImageURLs(imageConuntPerFetch: Int, timesOfFetch: Int) async
        -> AsyncThrowingStream<[CatImageModel], Error>
}
