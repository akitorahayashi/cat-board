import CatImageLoader
import CatImageScreener
import Foundation
import ScaryCatScreeningKit
import XCTest

final class CatImageScreenerTests: XCTestCase {
    var screener: CatImageScreener!
    var mockImageLoader: MockCatImageLoader!

    override func setUp() {
        super.setUp()
        let testSettings = ScreeningSettings(isScreeningEnabled: true, scaryMode: false)
        screener = CatImageScreener(screeningSettings: testSettings)
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
        // テスト用のモックURLを作成
        let testURLs = [
            URL(string: "https://example.com/cat1.jpg")!,
            URL(string: "https://example.com/cat2.jpg")!,
        ]

        // MockCatImageLoaderを使用して画像データをロード
        let loadedImages = try await mockImageLoader.loadImageData(from: testURLs)

        let results = try await screener.screenImages(imageDataWithURLs: loadedImages)

        XCTAssertNotNil(results)
        XCTAssertTrue(results.count <= loadedImages.count)

        // 各結果がURLを含んでいることを確認
        for result in results {
            XCTAssertTrue(testURLs.contains(result))
        }
    }
}
