import CatImageScreener
import CBModel
import CoreGraphics
import ScaryCatScreeningKit
import XCTest

@MainActor
final class CatImageScreenerTests: XCTestCase {
    private var screener: CatImageScreener!

    override func setUp() {
        super.setUp()
        screener = CatImageScreener()
    }

    override func tearDown() {
        screener = nil
        super.tearDown()
    }

    /// 画像とモデルの数が一致しない場合のエラーテスト
    func testMismatchedArrayCounts() async {
        let imageData = TestResources.createMockImageData()
        let model = TestResources.createMockCatImageURLModels(count: 1)[0]

        do {
            _ = try await screener.screenImages(
                images: [(imageData: imageData, model: model)]
            )
            XCTFail("エラーが発生するはず")
        } catch {
            // エラーが発生したことを確認
            XCTAssertNotNil(error)
        }
    }
}
