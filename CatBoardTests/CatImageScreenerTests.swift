import CatAPIClient
import CatImageLoader
import CatImageScreener
import ScaryCatScreeningKit
import XCTest

final class CatImageScreenerTests: XCTestCase {
    var screener: CatImageScreener!

    override func setUp() {
        super.setUp()
        screener = CatImageScreener()
    }

    override func tearDown() {
        screener = nil
        super.tearDown()
    }

    /// スクリーナーが正しく初期化され、ScaryCatScreenerインスタンスを返すことを確認
    func testInitialScreener() async throws {
        let screener = try await screener.getScreener()

        XCTAssertNotNil(screener, "Screener should not be nil")
        XCTAssertTrue(screener is ScaryCatScreener, "Returned object should be a ScaryCatScreener")
    }

    /// スクリーナーがシングルトンパターンを維持し、複数回の呼び出しで同じインスタンスを返すことを確認
    func testScreenerSingleton() async throws {
        let firstScreener = try await screener.getScreener()
        let secondScreener = try await screener.getScreener()

        XCTAssertNotNil(firstScreener)
        XCTAssertNotNil(secondScreener)
        XCTAssertTrue(firstScreener === secondScreener, "Second call should return the same instance")
    }

    /// MockCatImageLoaderを使用して画像処理が正常に実行できることを確認
    func testProcessImageWithMockLoader() async throws {
        let mockLoader = MockCatImageLoader()
        // urlを取得するが、ロードせず、Dataが使われる
        let mockAPIClient = MockCatAPIClient()

        let testModels = try await mockAPIClient.fetchImageURLs(totalCount: 2, batchSize: 2)
        let loadedImages = try await mockLoader.loadImageData(from: testModels)
        let results = try await screener.screenImages(imageDataWithModels: loadedImages)

        XCTAssertNotNil(results, "Results should not be nil")
        XCTAssertTrue(results.count <= loadedImages.count, "Results count should not exceed input count")
    }
}
