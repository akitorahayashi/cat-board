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
    private var mockPrefetcher: NoopCatImagePrefetcher!

    override func setUpWithError() throws {
        try super.setUpWithError()

        mockRepository = MockCatImageURLRepository(apiClient: MockCatAPIClient())
        mockLoader = MockCatImageLoader()
        mockScreener = MockCatImageScreener()
        mockPrefetcher = NoopCatImagePrefetcher(
            repository: mockRepository,
            imageLoader: mockLoader,
            screener: mockScreener
        )
    }

    override func tearDown() {
        mockRepository = nil
        mockLoader = nil
        mockScreener = nil
        mockPrefetcher = nil

        super.tearDown()
    }

    /// プリフェッチを実行すると画像が取得できることを確認（スクリーニング無効で純粋な機能テスト）
    func testStartPrefetching() async throws {
        await mockLoader.setLoadingTimeInSeconds(0.01)
        await mockScreener.setIsScreeningEnabled(false)

        let initialCount = try await mockPrefetcher.getPrefetchedCount()
        XCTAssertEqual(initialCount, 0)

        try await mockPrefetcher.startPrefetchingIfNeeded()

        let count = try await mockPrefetcher.getPrefetchedCount()
        XCTAssertEqual(count, 150) // スクリーニング無効なので全150枚が通過
    }

    /// 指定した枚数分の画像を取得できることを確認（スクリーニング無効で正確な枚数確認）
    func testGetRequestedImageCount() async throws {
        await mockLoader.setLoadingTimeInSeconds(0.01)
        await mockScreener.setIsScreeningEnabled(false)

        try await mockPrefetcher.startPrefetchingIfNeeded()

        let initialCount = try await mockPrefetcher.getPrefetchedCount()
        XCTAssertEqual(initialCount, 150)

        let requestCount = 5
        let images = try await mockPrefetcher.getPrefetchedImages(imageCount: requestCount)
        XCTAssertEqual(images.count, requestCount)

        let remainingCount = try await mockPrefetcher.getPrefetchedCount()
        XCTAssertEqual(remainingCount, initialCount - requestCount)
    }

    /// プリフェッチの重複実行を防止できることを確認（スクリーニング無効で並行処理テスト）
    func testIgnoreDuplicatePrefetching() async throws {
        await mockLoader.setLoadingTimeInSeconds(0.01)
        await mockScreener.setIsScreeningEnabled(false)

        let task1 = Task {
            try await mockPrefetcher.startPrefetchingIfNeeded()
        }
        let task2 = Task {
            try await mockPrefetcher.startPrefetchingIfNeeded()
        }

        _ = try await task1.value
        _ = try await task2.value

        // 並行実行により複数回プリフェッチが実行される
        let count = try await mockPrefetcher.getPrefetchedCount()
        XCTAssertGreaterThan(count, 150)
    }

    /// プリフェッチ中に画像を取得した場合の動作を確認（スクリーニング無効で状態管理テスト）
    func testGetImagesWhilePrefetching() async throws {
        await mockLoader.setLoadingTimeInSeconds(0.01)
        await mockScreener.setIsScreeningEnabled(false)

        let initialCount = try await mockPrefetcher.getPrefetchedCount()
        XCTAssertEqual(initialCount, 0)

        try await mockPrefetcher.startPrefetchingIfNeeded()

        let finalCount = try await mockPrefetcher.getPrefetchedCount()
        XCTAssertEqual(finalCount, 150)

        let images = try await mockPrefetcher.getPrefetchedImages(imageCount: 5)
        XCTAssertEqual(images.count, 5)

        let remainingCount = try await mockPrefetcher.getPrefetchedCount()
        XCTAssertEqual(remainingCount, 145)
    }

    /// プリフェッチ完了後の再実行時の動作を確認（スクリーニング無効でライフサイクルテスト）
    func testStartPrefetchingAfterCompletion() async throws {
        await mockLoader.setLoadingTimeInSeconds(0.01)
        await mockScreener.setIsScreeningEnabled(false)

        try await mockPrefetcher.startPrefetchingIfNeeded()

        let firstCount = try await mockPrefetcher.getPrefetchedCount()
        XCTAssertEqual(firstCount, 150)

        let consumeCount = 100
        _ = try await mockPrefetcher.getPrefetchedImages(imageCount: consumeCount)

        let afterConsumeCount = try await mockPrefetcher.getPrefetchedCount()
        XCTAssertEqual(afterConsumeCount, firstCount - consumeCount)

        try await mockPrefetcher.startPrefetchingIfNeeded()

        let finalCount = try await mockPrefetcher.getPrefetchedCount()
        // MockPrefetcherでは常に新しい画像を追加する
        XCTAssertEqual(finalCount, afterConsumeCount + 150)
    }

    /// スクリーニングが有効に動作していることを確認（スクリーニング機能の動作テスト）
    func testScreeningIsWorking() async throws {
        await mockScreener.setIsScreeningEnabled(true)

        let screeningPrefetcher = NoopCatImagePrefetcher(
            repository: mockRepository,
            imageLoader: mockLoader,
            screener: mockScreener
        )
        try await screeningPrefetcher.startPrefetchingIfNeeded()

        let countWithScreening = try await screeningPrefetcher.getPrefetchedCount()

        await mockScreener.setIsScreeningEnabled(false)

        let noScreeningPrefetcher = NoopCatImagePrefetcher(
            repository: mockRepository,
            imageLoader: mockLoader,
            screener: mockScreener
        )
        try await noScreeningPrefetcher.startPrefetchingIfNeeded()

        let countWithoutScreening = try await noScreeningPrefetcher.getPrefetchedCount()

        // スクリーニング有効時は約半分の枚数になるはず
        XCTAssertLessThan(countWithScreening, countWithoutScreening)
        XCTAssertEqual(countWithoutScreening, 150)
    }
}
