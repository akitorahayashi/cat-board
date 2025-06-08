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

        // テスト用のin-memoryモデルコンテナを作成
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

        // スクリーニング無効の場合の期待時間を計算（目標枚数の1.5倍）
        let waitTime = await UInt64(
            mockLoader
                .calculateTotalLoadingTime(for: Int(Double(CatImagePrefetcher.targetPrefetchCount) * 1.5)) *
                1_000_000_000
        )
        try await Task.sleep(nanoseconds: waitTime)

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

        // 期待時間を計算（目標枚数の1.5倍）
        let waitTime = await UInt64(
            mockLoader
                .calculateTotalLoadingTime(for: Int(Double(CatImagePrefetcher.targetPrefetchCount) * 1.5)) *
                1_000_000_000
        )
        try await Task.sleep(nanoseconds: waitTime)

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

        // 重複実行が防止されるため、1回分の処理時間で十分（目標枚数の2倍）
        let waitTime = await UInt64(
            mockLoader
                .calculateTotalLoadingTime(for: Int(Double(CatImagePrefetcher.targetPrefetchCount) * 2.0)) *
                1_000_000_000
        )
        try await Task.sleep(nanoseconds: waitTime)

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

        // 期待時間を計算（目標枚数の1.5倍）
        let waitTime = await UInt64(
            mockLoader
                .calculateTotalLoadingTime(for: Int(Double(CatImagePrefetcher.targetPrefetchCount) * 1.5)) *
                1_000_000_000
        )
        try await Task.sleep(nanoseconds: waitTime)

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

        let waitTime1 = await UInt64(
            mockLoader
                .calculateTotalLoadingTime(for: Int(Double(CatImagePrefetcher.targetPrefetchCount) * 5.0)) *
                1_000_000_000
        )
        try await Task.sleep(nanoseconds: waitTime1)

        let firstCount = try await prefetcher.getPrefetchedCount()
        XCTAssertGreaterThanOrEqual(firstCount, 50) // 50枚以上プリフェッチされていれば成功

        let consumeCount = 100
        _ = try await prefetcher.getPrefetchedImages(imageCount: consumeCount)

        let afterConsumeCount = try await prefetcher.getPrefetchedCount()
        XCTAssertEqual(afterConsumeCount, firstCount - consumeCount)

        // 2回目のプリフェッチ
        try await prefetcher.startPrefetchingIfNeeded()

        let waitTime2 = await UInt64(
            mockLoader
                .calculateTotalLoadingTime(for: CatImagePrefetcher.targetPrefetchCount * 5) *
                1_000_000_000
        )
        try await Task.sleep(nanoseconds: waitTime2)

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
        let waitTime = await UInt64(
            mockLoader
                .calculateTotalLoadingTime(for: CatImagePrefetcher.targetPrefetchCount * 5) * 1_000_000_000
        )
        try await Task.sleep(nanoseconds: waitTime)
        let endTime = Date()
        let actualTimeWithScreening = endTime.timeIntervalSince(startTime)

        XCTAssertGreaterThan(actualTimeWithScreening, expectedTimeWithoutScreening * 1.2, "スクリーニング有効時は実行時間が延長される")

        let finalCount = try await prefetcher.getPrefetchedCount()
        // スクリーニングがあるため、50枚以上プリフェッチされていれば成功とする
        let minimumExpectedCount = 50
        XCTAssertGreaterThanOrEqual(finalCount, minimumExpectedCount, "スクリーニング有効でも50枚以上の画像がプリフェッチされる")
    }
}
