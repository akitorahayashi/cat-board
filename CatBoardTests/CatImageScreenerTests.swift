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
        // モックのCGImageを作成
        let cgImage = TestResources.createMockCGImage()
        let model = TestResources.createMockCatImageURLModels(count: 1)[0]

        do {
            _ = try await screener.screenImages(
                cgImages: [cgImage],
                models: [model, model] // モデルが1つ多い
            )
            XCTFail("エラーが発生するはず")
        } catch {
            // エラーが発生したことを確認
            XCTAssertNotNil(error)
        }
    }
}
