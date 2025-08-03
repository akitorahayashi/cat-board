import CatAPIClient
import CatImageLoader
import CatImagePrefetcher
import CatImageScreener
import CatImageURLRepository
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
    var testScreeningSettings: ScreeningSettings!

    override func setUpWithError() throws {
        try super.setUpWithError()
        mockRepository = MockCatImageURLRepository(apiClient: MockCatAPIClient())
        testScreeningSettings = ScreeningSettings(isScreeningEnabled: false, scaryMode: false)
        mockScreener = MockCatImageScreener(screeningSettings: testScreeningSettings)
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
        testScreeningSettings = nil

        super.tearDown()
    }

    func testLoadInitialImages() async {
        XCTAssertTrue(viewModel.imageURLsToShow.isEmpty)

        viewModel.loadInitialImages()

        await waitFor({
            self.viewModel.imageURLsToShow.count == GalleryViewModel.targetInitialDisplayCount
        }, description: "初期画像が目標枚数読み込まれるべき")

        XCTAssertEqual(viewModel.imageURLsToShow.count, GalleryViewModel.targetInitialDisplayCount)
        XCTAssertFalse(viewModel.isInitializing)
    }

    func testFetchAdditionalImages() async {
        viewModel.loadInitialImages()
        await waitFor { self.viewModel.imageURLsToShow.count == GalleryViewModel.targetInitialDisplayCount }
        let initialCount = viewModel.imageURLsToShow.count

        await viewModel.fetchAdditionalImages()
        await waitFor { self.viewModel.imageURLsToShow.count == initialCount + GalleryViewModel.batchDisplayCount }

        XCTAssertEqual(viewModel.imageURLsToShow.count, initialCount + GalleryViewModel.batchDisplayCount)
        XCTAssertFalse(viewModel.isAdditionalFetching)
    }

    func testClearDisplayedImages() async {
        viewModel.loadInitialImages()
        await waitFor { self.viewModel.imageURLsToShow.count == GalleryViewModel.targetInitialDisplayCount }
        XCTAssertFalse(viewModel.imageURLsToShow.isEmpty)

        viewModel.clearDisplayedImages()

        XCTAssertTrue(viewModel.imageURLsToShow.isEmpty)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testMaxImageCountReached() async {
        viewModel.loadInitialImages()
        await waitFor { self.viewModel.imageURLsToShow.count == GalleryViewModel.targetInitialDisplayCount }

        // isInitializing が true になるまで追加取得を試みる（最大30回試行）
        for _ in 0 ..< 30 {
            if viewModel.isInitializing { break }
            await viewModel.fetchAdditionalImages()
        }

        // isInitializingが最終的にtrueになるのを待つ
        await waitFor({
            self.viewModel.isInitializing
        }, description: "MaxImageCountに達した後にisInitializingがtrueになるべき")

        // 画像がクリアされ、再読み込みが開始されていることを確認
        XCTAssertTrue(viewModel.isInitializing)
        XCTAssertFalse(viewModel.isAdditionalFetching)
    }

    func testScreeningInInitialImages() async throws {
        testScreeningSettings.isScreeningEnabled = true

        viewModel.loadInitialImages()
        await waitFor { !self.viewModel.isInitializing && !self.viewModel.imageURLsToShow.isEmpty }

        let finalCount = viewModel.imageURLsToShow.count

        // スクリーニングにより、目標枚数以下になる可能性がある
        XCTAssertLessThanOrEqual(finalCount, GalleryViewModel.targetInitialDisplayCount)
        XCTAssertFalse(viewModel.isInitializing)
    }

    func testScreeningInAdditionalImages() async throws {
        testScreeningSettings.isScreeningEnabled = true

        viewModel.loadInitialImages()
        await waitFor { !self.viewModel.isInitializing && !self.viewModel.imageURLsToShow.isEmpty }
        let initialCount = viewModel.imageURLsToShow.count

        await viewModel.fetchAdditionalImages()
        await waitFor { !self.viewModel.isAdditionalFetching }

        let addedCount = viewModel.imageURLsToShow.count - initialCount

        // スクリーニングにより、追加画像数が目標以下になる
        XCTAssertLessThanOrEqual(addedCount, GalleryViewModel.batchDisplayCount)
        XCTAssertFalse(viewModel.isAdditionalFetching)
    }
}

private extension GalleryViewModelTests {
    func waitFor(
        _ condition: @escaping () -> Bool,
        timeout: TimeInterval = 20.0,
        pollInterval: TimeInterval = 0.1,
        description: String = "Condition was not met within the timeout period."
    ) async {
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if condition() {
                return
            }
            try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
        }
        XCTFail(description)
    }
}
