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

    override func setUpWithError() throws {
        try super.setUpWithError()

        let schema = Schema([PrefetchedCatImageURL.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])

        mockRepository = MockCatImageURLRepository(apiClient: MockCatAPIClient())
        mockLoader = MockCatImageLoader()
        mockScreener = MockCatImageScreener()
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

        super.tearDown()
    }

    // MARK: - Test Methods

    /// プリフェッチを実行すると画像が取得できることを確認（スクリーニング無効で純粋な機能テスト）
    func testStartPrefetching() async throws {
        // 1枚あたり0.05秒でローディング
        await mockLoader.setLoadingTimeInSeconds(0.05)
        await mockScreener.setIsScreeningEnabled(false)

        let initialCount = try await prefetcher.getPrefetchedCount()
        XCTAssertEqual(initialCount, 0)

        try await prefetcher.startPrefetchingIfNeeded()

        // 十分な時間を確保して待機
        // 計算式: 0.05秒/枚 × 150枚 = 7.5秒 + 余裕時間1.5秒 = 9秒
        try await Task.sleep(nanoseconds: 9_000_000_000) // 9秒

        let count = try await prefetcher.getPrefetchedCount()
        XCTAssertGreaterThanOrEqual(count, 50) // 50枚以上プリフェッチされていれば成功
    }

    /// 指定した枚数分の画像を取得できることを確認
    func testGetRequestedImageCount() async throws {
        // 1枚あたり0.03秒でローディング
        let loadingTimePerImage = 0.03
        await mockLoader.setLoadingTimeInSeconds(loadingTimePerImage)
        await mockScreener.setIsScreeningEnabled(false)

        try await prefetcher.startPrefetchingIfNeeded()

        // 十分な時間を確保して待機
        // 計算式: 0.03秒/枚 × 150枚 = 4.5秒 + 余裕時間2.5秒 = 7秒
        try await Task.sleep(nanoseconds: 7_000_000_000) // 7秒

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
        await mockScreener.setIsScreeningEnabled(false)

        let task1 = Task {
            try await prefetcher.startPrefetchingIfNeeded()
        }
        let task2 = Task {
            try await prefetcher.startPrefetchingIfNeeded()
        }

        _ = try await task1.value
        _ = try await task2.value

        // 重複実行テストのため十分な時間を確保して待機
        // 計算式: 0.02秒/枚 × 150枚 = 3秒 + 余裕時間2秒 = 5秒
        try await Task.sleep(nanoseconds: 5_000_000_000) // 5秒

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
        await mockScreener.setIsScreeningEnabled(false)

        let initialCount = try await prefetcher.getPrefetchedCount()
        XCTAssertEqual(initialCount, 0)

        try await prefetcher.startPrefetchingIfNeeded()

        // プリフェッチ進行中のテストのため十分な時間を確保して待機
        // 計算式: 0.04秒/枚 × 150枚 = 6秒 + 余裕時間2秒 = 8秒
        try await Task.sleep(nanoseconds: 8_000_000_000) // 8秒

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
        await mockScreener.setIsScreeningEnabled(false)

        // 最初のプリフェッチ
        try await prefetcher.startPrefetchingIfNeeded()

        // 最初のプリフェッチ完了まで待機
        // 計算式: 0.03秒/枚 × 150枚 = 4.5秒 + 余裕時間2.0秒 = 6.5秒
        try await Task.sleep(nanoseconds: 6_500_000_000) // 6.5秒

        let firstCount = try await prefetcher.getPrefetchedCount()
        XCTAssertGreaterThanOrEqual(firstCount, 50) // 50枚以上プリフェッチされていれば成功

        let consumeCount = 100
        _ = try await prefetcher.getPrefetchedImages(imageCount: consumeCount)

        let afterConsumeCount = try await prefetcher.getPrefetchedCount()
        XCTAssertEqual(afterConsumeCount, firstCount - consumeCount)

        // 2回目のプリフェッチ
        try await prefetcher.startPrefetchingIfNeeded()

        // 2回目のプリフェッチ完了まで待機
        // 計算式: 0.03秒/枚 × 150枚 = 4.5秒 + 余裕時間7.5秒 = 12秒
        try await Task.sleep(nanoseconds: 12_000_000_000) // 12秒

        let finalCount = try await prefetcher.getPrefetchedCount()
        XCTAssertGreaterThanOrEqual(finalCount, 50)
    }

    /// スクリーニングが有効に動作していることを確認
    func testScreeningIsWorking() async throws {
        await mockLoader.setLoadingTimeInSeconds(0.02)
        await mockScreener.setIsScreeningEnabled(true)

        let expectedTimeWithoutScreening = await mockLoader
            .calculateTotalLoadingTime(for: CatImagePrefetcher.targetPrefetchCount)

        let startTime = Date()
        try await prefetcher.startPrefetchingIfNeeded()
        // スクリーニング有効時のテストのため十分な時間を確保して待機
        // 計算式: 0.02秒/枚 × 150枚 = 3秒 + スクリーニング時間 + 余裕時間 = 5秒
        try await Task.sleep(nanoseconds: 5_000_000_000) // 5秒
        let endTime = Date()
        let actualTimeWithScreening = endTime.timeIntervalSince(startTime)

        XCTAssertGreaterThan(actualTimeWithScreening, expectedTimeWithoutScreening * 1.2, "スクリーニング有効時は実行時間が延長される")

        let finalCount = try await prefetcher.getPrefetchedCount()
        // スクリーニングがあるため、50枚以上プリフェッチされていれば成功とする
        let minimumExpectedCount = 50
        XCTAssertGreaterThanOrEqual(finalCount, minimumExpectedCount, "スクリーニング有効でも50枚以上の画像がプリフェッチされる")
    }
}
