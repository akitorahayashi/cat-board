import CatAPIClient
import CatImageLoader
import CatImagePrefetcher
import CatImageScreener
import CatImageURLRepository
import CatURLImageModel
import SwiftData
import XCTest

@testable import CatBoardApp

@MainActor
final class GalleryViewModelTests: XCTestCase {
    var viewModel: GalleryViewModel!
    var mockLoader: MockCatImageLoader!
    var mockRepository: MockCatImageURLRepository!
    var mockScreener: MockCatImageScreener!
    var mockPrefetcher: NoopCatImagePrefetcher!

    override func setUpWithError() throws {
        try super.setUpWithError()
        mockRepository = MockCatImageURLRepository(apiClient: MockCatAPIClient())
        mockScreener = MockCatImageScreener()
        mockLoader = MockCatImageLoader()
        mockPrefetcher = NoopCatImagePrefetcher(
            repository: mockRepository,
            imageLoader: mockLoader,
            screener: mockScreener
        )
        viewModel = GalleryViewModel(
            repository: mockRepository,
            imageLoader: mockLoader,
            screener: mockScreener,
            prefetcher: mockPrefetcher
        )
    }

    override func tearDown() {
        viewModel = nil
        mockLoader = nil
        mockRepository = nil
        mockScreener = nil
        mockPrefetcher = nil

        super.tearDown()
    }

    func testLoadInitialImages() async {
        await mockLoader.setLoadingTimeInSeconds(0.01)
        await mockScreener.setIsScreeningEnabled(false)

        XCTAssertTrue(viewModel.imageURLsToShow.isEmpty)

        viewModel.loadInitialImages()

        // 計算根拠: スクリーニング無効なので30枚処理 × 0.01秒/枚 = 0.3秒 + バッファ
        var attempts = 0
        while viewModel.imageURLsToShow.count < GalleryViewModel.targetInitialDisplayCount, attempts < 20 {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // CIの実行時間を考慮して2秒に設定
            attempts += 1
        }

        XCTAssertEqual(viewModel.imageURLsToShow.count, GalleryViewModel.targetInitialDisplayCount)
        XCTAssertFalse(viewModel.isInitializing)
    }

    func testFetchAdditionalImages() async {
        await mockLoader.setLoadingTimeInSeconds(0.01)
        await mockScreener.setIsScreeningEnabled(false)

        viewModel.loadInitialImages()
        // 初期読み込み完了まで待機: 30枚処理 × 0.01秒/枚 = 0.3秒 + バッファ = 2秒 (CIの実行時間を考慮)
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        let initialCount = viewModel.imageURLsToShow.count

        await viewModel.fetchAdditionalImages()

        XCTAssertEqual(viewModel.imageURLsToShow.count, initialCount + GalleryViewModel.batchDisplayCount)
        XCTAssertFalse(viewModel.isAdditionalFetching)
    }

    func testClearDisplayedImages() async {
        await mockLoader.setLoadingTimeInSeconds(0.01)
        await mockScreener.setIsScreeningEnabled(false)

        viewModel.loadInitialImages()
        // 初期読み込み完了まで待機: 30枚処理 × 0.01秒/枚 = 0.3秒 + バッファ = 2秒 (CIの実行時間を考慮)
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        XCTAssertFalse(viewModel.imageURLsToShow.isEmpty)

        viewModel.clearDisplayedImages()

        XCTAssertTrue(viewModel.imageURLsToShow.isEmpty)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testMaxImageCountReached() async {
        await mockLoader.setLoadingTimeInSeconds(0.01)
        await mockScreener.setIsScreeningEnabled(false)

        viewModel.loadInitialImages()
        // 初期読み込み完了まで待機: 30枚処理 × 0.01秒/枚 = 0.3秒 + バッファ = 2秒 (CIの実行時間を考慮)
        try? await Task.sleep(nanoseconds: 2_000_000_000)

        for _ in 0 ..< (GalleryViewModel.maxImageCount / GalleryViewModel.batchDisplayCount) {
            await viewModel.fetchAdditionalImages()
        }

        await viewModel.fetchAdditionalImages()

        // 画像がクリアされ、再読み込みが開始されていることを確認
        XCTAssertTrue(viewModel.isInitializing)
        XCTAssertFalse(viewModel.isAdditionalFetching)
        XCTAssertLessThanOrEqual(viewModel.imageURLsToShow.count, GalleryViewModel.maxImageCount)
    }

    func testScreeningInInitialImages() async throws {
        await mockLoader.setLoadingTimeInSeconds(0.01)
        await mockScreener.setIsScreeningEnabled(true)

        viewModel.loadInitialImages()

        // スクリーニング有効時は目標枚数の約2倍処理: 60枚 × 0.01秒 = 0.6秒 + バッファ = 2秒 (CIの実行時間を考慮)
        try? await Task.sleep(nanoseconds: 2_000_000_000)

        let finalCount = viewModel.imageURLsToShow.count

        // スクリーニングにより、目標枚数以下になる可能性がある
        XCTAssertLessThanOrEqual(finalCount, GalleryViewModel.targetInitialDisplayCount)
        XCTAssertFalse(viewModel.isInitializing)
    }

    func testScreeningInAdditionalImages() async throws {
        await mockLoader.setLoadingTimeInSeconds(0.01)
        await mockScreener.setIsScreeningEnabled(true)

        viewModel.loadInitialImages()

        // 初期読み込み完了まで待機: 60枚 × 0.01秒 = 0.6秒 + バッファ = 2秒 (CIの実行時間を考慮)
        try? await Task.sleep(nanoseconds: 2_000_000_000)

        let initialCount = viewModel.imageURLsToShow.count

        await viewModel.fetchAdditionalImages()

        let addedCount = viewModel.imageURLsToShow.count - initialCount

        // スクリーニングにより、追加画像数が目標以下になる
        XCTAssertLessThanOrEqual(addedCount, GalleryViewModel.batchDisplayCount)
        XCTAssertFalse(viewModel.isAdditionalFetching)
    }
}
