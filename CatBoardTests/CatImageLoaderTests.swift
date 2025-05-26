import CatAPIClient
import CatImageLoader
import CatImageScreener
import CatImageURLRepository
import CBModel
import SwiftData
import XCTest

final class CatImageLoaderTests: XCTestCase {
    private var imageLoader: CatImageLoader!
    private var mockRepository: MockCatImageURLRepository!
    private var mockImageClient: MockCatAPIClient!
    private var mockScreener: MockCatImageScreener!
    private var modelContainer: ModelContainer!

    override func setUpWithError() throws {
        let schema = Schema([CatImageURLEntity.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        mockRepository = MockCatImageURLRepository()
        mockImageClient = MockCatAPIClient()
        mockScreener = MockCatImageScreener()

        imageLoader = CatImageLoader(
            modelContainer: modelContainer,
            repository: mockRepository,
            screener: mockScreener,
            imageClient: mockImageClient
        )
    }

    override func tearDown() {
        imageLoader = nil
        mockRepository = nil
        mockImageClient = nil
        mockScreener = nil
        modelContainer = nil
    }

    // プリフェッチの開始と最初のバッチの処理を確認する
    func testPrefetchingTrigger() async {
        // 初期状態の確認
        var count = await imageLoader.getPrefetchedCount()
        XCTAssertEqual(count, 0, "初期状態ではプリフェッチ数は0")

        // モックデータの設定
        let batchSize = 10
        let mockImages = TestResources.createMockCatImageURLModels(count: batchSize)
        mockRepository.getNextImageURLsResult = mockImages
        mockScreener.screeningResult = mockImages

        // プリフェッチ開始
        await imageLoader.startPrefetchingIfNeeded()

        // 最初のバッチの完了を待つ
        try? await Task.sleep(nanoseconds: 3_000_000_000) // 3秒待機

        // 最初のバッチのプリフェッチ数を確認
        count = await imageLoader.getPrefetchedCount()
        XCTAssertGreaterThanOrEqual(count, batchSize, "最初のバッチの処理が開始されている")
    }

    // 目標枚数までの進捗と制限を確認する
    func testPrefetchingLimit() async {
        // 目標枚数分のモックデータを設定
        let targetCount = 150
        let mockImages = TestResources.createMockCatImageURLModels(count: targetCount)
        mockRepository.getNextImageURLsResult = mockImages
        mockScreener.screeningResult = mockImages

        // プリフェッチ開始
        await imageLoader.startPrefetchingIfNeeded()

        // プリフェッチの完了を待つ
        try? await Task.sleep(nanoseconds: 3_000_000_000) // 3秒待機

        // プリフェッチ数の確認
        let count = await imageLoader.getPrefetchedCount()
        XCTAssertEqual(count, targetCount, "目標枚数までプリフェッチされる")

        // 追加のプリフェッチトリガー
        await imageLoader.startPrefetchingIfNeeded()
        let newCount = await imageLoader.getPrefetchedCount()
        XCTAssertEqual(newCount, targetCount, "目標枚数に達したら追加のプリフェッチは行われない")
    }

    // 画像のダウンロードに失敗した場合の動作を確認する
    func testPrefetchingWithDownloadFailure() async {
        // モックデータの設定
        let batchSize = 10
        let mockImages = TestResources.createMockCatImageURLModels(count: batchSize)
        mockRepository.getNextImageURLsResult = mockImages

        // プリフェッチ開始
        await imageLoader.startPrefetchingIfNeeded()

        // 最初のバッチの完了を待つ
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒待機

        // プリフェッチ数の確認
        let count = await imageLoader.getPrefetchedCount()
        XCTAssertEqual(count, 0, "画像のダウンロードに失敗した場合、プリフェッチ数は0")
    }
}
