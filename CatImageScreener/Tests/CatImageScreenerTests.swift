import CatImageScreener
import CatURLImageModel
import Foundation
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
        let firstScreener = try await screener.getScreener()
        XCTAssertNotNil(firstScreener)

        let secondScreener = try await screener.getScreener()
        XCTAssertNotNil(secondScreener)
        XCTAssertTrue(firstScreener === secondScreener)
    }

    /// モック画像データを使用して画像処理が正常に実行できることを確認
    func testProcessImageWithMockData() async throws {
        // テスト用のモック画像データを作成
        let testModels = [
            CatImageURLModel(imageURL: "https://example.com/cat1.jpg"),
            CatImageURLModel(imageURL: "https://example.com/cat2.jpg")
        ]
        
        // 簡単なテスト用画像データを作成
        let mockImageData = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) // PNGヘッダー
        let loadedImages = testModels.map { ($0, mockImageData) }
        
        let results = try await screener.screenImages(imageDataWithModels: loadedImages)

        XCTAssertNotNil(results)
        XCTAssertTrue(results.count <= loadedImages.count)
    }
}
