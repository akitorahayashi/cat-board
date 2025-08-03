import CatAPIClient
import CatImageLoader
import CatImagePrefetcher
import CatImageScreener
import CatImageURLRepository
import CatURLImageModel
import SwiftData
import XCTest

final class CatImagePrefetcherTests: XCTestCase {
    private var mockRepository: MockCatImageURLRepository!
    private var mockLoader: MockCatImageLoader!
    private var mockScreener: MockCatImageScreener!
    private var prefetcher: CatImagePrefetcher!
    private var modelContainer: ModelContainer!
    private var testScreeningSettings: ScreeningSettings!

    /// CI環境では長めに、ローカル環境では短めに設定
    private static let bufferTimeInSeconds: Double = 12.0

    override func setUpWithError() throws {
        try super.setUpWithError()

        let schema = Schema([PrefetchedCatImageURL.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])

        mockRepository = MockCatImageURLRepository(apiClient: MockCatAPIClient())
        mockLoader = MockCatImageLoader()
        testScreeningSettings = ScreeningSettings(isScreeningEnabled: false, scaryMode: false)
        mockScreener = MockCatImageScreener(screeningSettings: testScreeningSettings)
        prefetcher = CatImagePrefetcher(
            repository: mockRepository,
            imageLoader: mockLoader,
            screener: mockScreener,
            modelContainer: modelContainer
        )
    }

    override func tearDown() {
        mockRepository = nil
        mockLoader = nil
        mockScreener = nil
        prefetcher = nil
        modelContainer = nil
        testScreeningSettings = nil

        super.tearDown()
    }

    // MARK: - Test Methods

    /// プリフェッチを実行すると画像が取得できることを確認（スクリーニング無効で純粋な機能テスト）
    func testStartPrefetching() async throws {
        // 1枚あたり0.05秒でローディング
        await mockLoader.setLoadingTimeInSeconds(0.05)

        let initialCount = try await prefetcher.getPrefetchedCount()
        XCTAssertEqual(initialCount, 0)

        try await prefetcher.startPrefetchingIfNeeded()

        // 十分な時間を確保して待機
        // 計算式: 0.05秒/枚 × 150枚 = 7.5秒 + 余裕時間 = 20秒
        try await Task.sleep(nanoseconds: UInt64(20 * 1_000_000_000))

        let count = try await prefetcher.getPrefetchedCount()
        XCTAssertGreaterThanOrEqual(count, 50) // 50枚以上プリフェッチされていれば成功
    }

    /// 指定した枚数分の画像を取得できることを確認
    func testGetRequestedImageCount() async throws {
        // 1枚あたり0.03秒でローディング
        let loadingTimePerImage = 0.03
        await mockLoader.setLoadingTimeInSeconds(loadingTimePerImage)

        try await prefetcher.startPrefetchingIfNeeded()

        // 十分な時間を確保して待機
        // 計算式: 0.03秒/枚 × 150枚 = 4.5秒 + 余裕時間 = 12.5秒
        let totalWaitTime = 4.5 + Self.bufferTimeInSeconds
        try await Task.sleep(nanoseconds: UInt64(totalWaitTime * 1_000_000_000))

        let initialCount = try await prefetcher.getPrefetchedCount()
        XCTAssertGreaterThanOrEqual(initialCount, 50) // 50枚以上プリフェッチされていれば成功

        let requestCount = 5
        let images = try await prefetcher.getPrefetchedImages(imageCount: requestCount)
        XCTAssertEqual(images.count, requestCount)

        let remainingCount = try await prefetcher.getPrefetchedCount()
        XCTAssertEqual(remainingCount, initialCount - requestCount)
    }

    /// プリフェッチの重複実行を防止できることを確認（スクリーニング無効で並行処理テスト）
    func testIgnoreDuplicatePrefetching() async throws {
        // 1枚あたり0.02秒でローディング
        let loadingTimePerImage = 0.02
        await mockLoader.setLoadingTimeInSeconds(loadingTimePerImage)

        let task1 = Task {
            try await prefetcher.startPrefetchingIfNeeded()
        }
        let task2 = Task {
            try await prefetcher.startPrefetchingIfNeeded()
        }

        _ = try await task1.value
        _ = try await task2.value

        // 重複実行テストのため十分な時間を確保して待機
        // 計算式: 0.02秒/枚 × 150枚 = 3秒 + 余裕時間 = 11秒
        let totalWaitTime = 3.0 + Self.bufferTimeInSeconds
        try await Task.sleep(nanoseconds: UInt64(totalWaitTime * 1_000_000_000))

        // 重複実行が防止されるため、50枚以上プリフェッチされていれば成功
        let count = try await prefetcher.getPrefetchedCount()
        XCTAssertGreaterThanOrEqual(count, 50, "重複実行が防止され、50枚以上がプリフェッチされる")
        XCTAssertLessThan(
            count,
            CatImagePrefetcher.targetPrefetchCount + CatImagePrefetcher.prefetchBatchCount,
            "重複実行により過度に多くの画像がプリフェッチされることはない"
        )
    }

    /// プリフェッチ中に画像を取得した場合の動作を確認
    func testGetImagesWhilePrefetching() async throws {
        // 1枚あたり0.04秒でローディング
        let loadingTimePerImage = 0.04
        await mockLoader.setLoadingTimeInSeconds(loadingTimePerImage)

        let initialCount = try await prefetcher.getPrefetchedCount()
        XCTAssertEqual(initialCount, 0)

        try await prefetcher.startPrefetchingIfNeeded()

        // プリフェッチ進行中のテストのため十分な時間を確保して待機
        // 計算式: 0.04秒/枚 × 150枚 = 6秒 + 余裕時間 = 14秒
        let totalWaitTime = 6.0 + Self.bufferTimeInSeconds
        try await Task.sleep(nanoseconds: UInt64(totalWaitTime * 1_000_000_000))

        let finalCount = try await prefetcher.getPrefetchedCount()
        XCTAssertGreaterThanOrEqual(finalCount, 50) // 50枚以上プリフェッチされていれば成功

        let images = try await prefetcher.getPrefetchedImages(imageCount: 5)
        XCTAssertEqual(images.count, 5)

        let remainingCount = try await prefetcher.getPrefetchedCount()
        XCTAssertEqual(remainingCount, finalCount - 5)
    }

    /// プリフェッチ完了後の再実行時の動作を確認
    func testStartPrefetchingAfterCompletion() async throws {
        // 1枚あたり0.03秒でローディング
        let loadingTimePerImage = 0.03
        await mockLoader.setLoadingTimeInSeconds(loadingTimePerImage)

        // 最初のプリフェッチ
        try await prefetcher.startPrefetchingIfNeeded()

        // 最初のプリフェッチ完了まで待機
        // 計算式: 0.03秒/枚 × 150枚 = 4.5秒 + 余裕時間 = 12.5秒
        let totalWaitTime = 4.5 + Self.bufferTimeInSeconds
        try await Task.sleep(nanoseconds: UInt64(totalWaitTime * 1_000_000_000))

        let firstCount = try await prefetcher.getPrefetchedCount()
        XCTAssertGreaterThanOrEqual(firstCount, 50) // 50枚以上プリフェッチされていれば成功

        let consumeCount = 100
        _ = try await prefetcher.getPrefetchedImages(imageCount: consumeCount)

        let afterConsumeCount = try await prefetcher.getPrefetchedCount()
        XCTAssertLessThanOrEqual(afterConsumeCount, firstCount - consumeCount)

        // 2回目のプリフェッチ
        try await prefetcher.startPrefetchingIfNeeded()

        // 2回目のプリフェッチ完了まで待機
        // 計算式: 0.03秒/枚 × 150枚 = 4.5秒 + 余裕時間 = 12.5秒
        try await Task.sleep(nanoseconds: UInt64(totalWaitTime * 1_000_000_000))

        let finalCount = try await prefetcher.getPrefetchedCount()
        XCTAssertGreaterThanOrEqual(finalCount, 50)
    }

    /// スクリーニングが有効に動作していることを確認
    func testScreeningIsWorking() async throws {
        await mockLoader.setLoadingTimeInSeconds(0.02)
        testScreeningSettings.isScreeningEnabled = true

        try await prefetcher.startPrefetchingIfNeeded()
        // スクリーニング有効時のテストのため十分な時間を確保して待機
        // 計算式: 0.02秒/枚 × 150枚 = 3秒 + スクリーニング時間 + 余裕時間 = 11秒
        let totalWaitTime = 3.0 + Self.bufferTimeInSeconds
        try await Task.sleep(nanoseconds: UInt64(totalWaitTime * 1_000_000_000))

        let screenedCount = try await prefetcher.getPrefetchedCount()
        let targetCount = CatImagePrefetcher.targetPrefetchCount

        // スクリーニングにより不適切な画像が除外され、枚数が減っていることを確認
        XCTAssertLessThan(screenedCount, targetCount, "スクリーニング有効時は不適切な画像が除外され枚数が減る")
        XCTAssertGreaterThan(screenedCount, 0, "スクリーニング有効でも適切な画像は取得される")
    }
}
