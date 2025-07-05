import CatImageLoader
import CatImageScreener
import CatURLImageModel
import Foundation
import ScaryCatScreeningKit
import XCTest

final class CatImageScreenerTests: XCTestCase {
    var screener: CatImageScreener!
    var mockImageLoader: MockCatImageLoader!

    override func setUp() {
        super.setUp()
        screener = CatImageScreener()
        mockImageLoader = MockCatImageLoader()
    }

    override func tearDown() {
        screener = nil
        mockImageLoader = nil
        super.tearDown()
    }

    /// スクリーナーが正しく初期化され、ScaryCatScreenerインスタンスを返すことを確認
    func testInitialScreener() async throws {
        let firstScreener = try await screener.getScreener()
        XCTAssertNotNil(firstScreener)

        let secondScreener = try await screener.getScreener()
        XCTAssertNotNil(secondScreener)
        XCTAssertTrue(firstScreener === secondScreener)
    }

    /// MockCatImageLoaderを使用して画像処理が正常に実行できることを確認
    func testProcessImageWithMockLoader() async throws {
        // テスト用のモックURLモデルを作成
        let testModels = [
            CatImageURLModel(imageURL: "https://example.com/cat1.jpg"),
            CatImageURLModel(imageURL: "https://example.com/cat2.jpg")
        ]

        // MockCatImageLoaderを使用して画像データをロード
        let loadedImages = try await mockImageLoader.loadImageData(from: testModels)

        let results = try await screener.screenImages(imageDataWithModels: loadedImages)

        XCTAssertNotNil(results)
        XCTAssertTrue(results.count <= loadedImages.count)
        
        // 各結果がCatImageURLModelを含んでいることを確認
        for result in results {
            XCTAssertTrue(testModels.contains(result))
        }
    }
}
