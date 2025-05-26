import XCTest

import CatAPIClient
import CatImageLoader
import CatImageURLRepository

@testable import CatBoardApp
import CBModel

@MainActor
final class GalleryViewModelTests: XCTestCase {
    private var viewModel: GalleryViewModel!
    private var mockRepository: MockCatImageURLRepository!
    private var mockLoader: MockCatImageLoader!

    override func setUp() {
        super.setUp()
        mockRepository = MockCatImageURLRepository()
        mockLoader = MockCatImageLoader()
        viewModel = GalleryViewModel(
            repository: mockRepository,
            loader: mockLoader
        )
    }

    override func tearDown() {
        viewModel = nil
        mockRepository = nil
        mockLoader = nil
        super.tearDown()
    }

    // MARK: - テストケース

    // 初期状態の検証
    func testInitialState() {
        XCTAssertTrue(viewModel.imageURLsToShow.isEmpty, "初期状態では画像URLの配列が空")
        XCTAssertNil(viewModel.errorMessage, "初期状態ではエラーメッセージがnil")
        XCTAssertFalse(viewModel.isLoading, "初期状態ではローディング中ではない")
    }

    // 初期画像の読み込み成功時の検証
    func testLoadInitialImagesSuccess() async {
        // モックデータの設定
        let expectedImages = TestResources.createMockCatImageURLModels(using: Array(TestResources.mockURLs.prefix(2)))
        mockLoader.loadImagesWithScreeningResult = expectedImages

        // 初期画像の読み込み開始
        viewModel.loadInitialImages()

        // 読み込み完了を待機
        try? await Task.sleep(nanoseconds: 100_000_000)

        // 検証
        XCTAssertEqual(viewModel.imageURLsToShow, expectedImages, "期待した画像URLが表示されている")
        XCTAssertNil(viewModel.errorMessage, "エラーメッセージがnil")
        XCTAssertFalse(viewModel.isLoading, "ローディングが完了している")
    }

    // 初期画像の読み込み失敗時の検証
    func testLoadInitialImagesFailure() async {
        // エラーの設定
        let expectedError = NSError(domain: "TestError", code: -1, userInfo: nil)
        mockLoader.loadImagesWithScreeningError = expectedError

        // 初期画像の読み込み開始
        viewModel.loadInitialImages()

        // 読み込み完了を待機
        try? await Task.sleep(nanoseconds: 100_000_000)

        // 検証
        XCTAssertTrue(viewModel.imageURLsToShow.isEmpty, "エラー時は画像URLの配列が空")
        XCTAssertEqual(viewModel.errorMessage, expectedError.localizedDescription, "エラーメッセージが正しく設定されている")
        XCTAssertFalse(viewModel.isLoading, "ローディングが完了している")
    }

    // 追加画像の読み込み失敗時の検証
    func testFetchAdditionalImagesFailure() async {
        // 初期画像の設定と読み込み
        let initialImages = TestResources.createMockCatImageURLModels(using: Array(TestResources.mockURLs.prefix(2)))
        mockLoader.loadImagesWithScreeningResult = initialImages
        viewModel.loadInitialImages()

        try? await Task.sleep(nanoseconds: 100_000_000)

        // エラーの設定
        let expectedError = NSError(domain: "TestError", code: -1, userInfo: nil)
        mockLoader.loadImagesWithScreeningError = expectedError

        // 追加画像の読み込み開始
        await viewModel.fetchAdditionalImages()

        try? await Task.sleep(nanoseconds: 100_000_000)

        // 検証
        XCTAssertEqual(viewModel.imageURLsToShow, initialImages, "エラー時は既存の画像が維持される")
        XCTAssertEqual(viewModel.errorMessage, expectedError.localizedDescription, "エラーメッセージが正しく設定されている")
        XCTAssertFalse(viewModel.isLoading, "ローディングが完了している")
    }

    // ローディング中の追加画像取得時の検証
    func testFetchAdditionalImagesWhenLoading() async {
        // 初期画像の設定と読み込み
        let initialImages = TestResources.createMockCatImageURLModels(using: Array(TestResources.mockURLs.prefix(2)))
        mockLoader.loadImagesWithScreeningResult = initialImages
        viewModel.loadInitialImages()

        try? await Task.sleep(nanoseconds: 100_000_000)

        // ローディング状態の設定
        viewModel.isLoading = true

        // 追加画像の読み込み開始
        await viewModel.fetchAdditionalImages()

        try? await Task.sleep(nanoseconds: 100_000_000)

        // 検証
        XCTAssertEqual(viewModel.imageURLsToShow, initialImages, "ローディング中は既存の画像が維持される")
        XCTAssertNil(viewModel.errorMessage, "エラーメッセージがnil")
        XCTAssertTrue(viewModel.isLoading, "ローディング状態が維持される")
    }

    // 画像のクリアと再読み込みの検証
    func testClearDisplayedImages() async {
        // 初期画像の設定と読み込み
        let initialImages = TestResources.createMockCatImageURLModels(using: Array(TestResources.mockURLs.prefix(2)))
        mockLoader.loadImagesWithScreeningResult = initialImages
        viewModel.loadInitialImages()

        try? await Task.sleep(nanoseconds: 100_000_000)

        // 新しい画像の設定
        let newImages = TestResources.createMockCatImageURLModels(using: Array(TestResources.mockURLs[2 ... 3]))
        mockLoader.loadImagesWithScreeningResult = newImages

        // 画像のクリアと再読み込み
        viewModel.clearDisplayedImages()

        try? await Task.sleep(nanoseconds: 100_000_000)

        // 検証
        XCTAssertEqual(viewModel.imageURLsToShow, newImages, "新しい画像が正しく表示されている")
        XCTAssertNil(viewModel.errorMessage, "エラーメッセージがnil")
        XCTAssertFalse(viewModel.isLoading, "ローディングが完了している")
    }

    // 画像の追加読み込みの検証
    func testAdditionalImageLoading() async {
        // 初期画像の設定と読み込み
        let initialImages = TestResources.createMockCatImageURLModels(using: Array(
            repeating: TestResources.mockURLs[0],
            count: GalleryViewModel.targetInitialDisplayCount
        ))
        mockLoader.loadImagesWithScreeningResult = initialImages
        viewModel.loadInitialImages()

        // 初期画像の読み込み完了を待機
        for _ in 0 ..< 10 {
            if viewModel.imageURLsToShow.count == GalleryViewModel.targetInitialDisplayCount {
                break
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        // 初期画像の検証
        XCTAssertEqual(
            viewModel.imageURLsToShow.count,
            GalleryViewModel.targetInitialDisplayCount,
            "初期画像が正しい数だけ表示されている"
        )
        XCTAssertEqual(viewModel.imageURLsToShow.first?.imageURL, TestResources.mockURLs[0], "最初の画像URLが正しい")

        // 新しい画像の設定
        let newImages = TestResources.createMockCatImageURLModels(using: Array(
            repeating: TestResources.mockURLs[0],
            count: GalleryViewModel.batchDisplayCount
        ))
        mockLoader.loadImagesWithScreeningResult = newImages

        // 追加画像の読み込み開始
        await viewModel.fetchAdditionalImages()

        // 追加画像の読み込み完了を待機
        for _ in 0 ..< 10 {
            if viewModel.imageURLsToShow.count == GalleryViewModel.targetInitialDisplayCount + GalleryViewModel
                .batchDisplayCount
            {
                break
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        // 追加画像の検証
        XCTAssertEqual(
            viewModel.imageURLsToShow.count,
            GalleryViewModel.targetInitialDisplayCount + GalleryViewModel.batchDisplayCount,
            "追加画像が正しい数だけ表示されている"
        )
        XCTAssertEqual(viewModel.imageURLsToShow.first?.imageURL, TestResources.mockURLs[0], "最初の画像は変更されていない")
        XCTAssertEqual(viewModel.imageURLsToShow.last?.imageURL, TestResources.mockURLs[0], "最後の画像が新しい画像")
        XCTAssertNil(viewModel.errorMessage, "エラーメッセージがnil")
        XCTAssertFalse(viewModel.isLoading, "ローディングが完了している")
    }

    // 最大画像数の制限検証
    func testMaxImageCount() async {
        // 初期画像の設定と読み込み
        let initialImages = TestResources.createMockCatImageURLModels(using: Array(
            repeating: TestResources.mockURLs[0],
            count: GalleryViewModel.targetInitialDisplayCount
        ))
        mockLoader.loadImagesWithScreeningResult = initialImages
        viewModel.loadInitialImages()

        // 初期画像の読み込み完了を待機
        for _ in 0 ..< 10 {
            if viewModel.imageURLsToShow.count == GalleryViewModel.targetInitialDisplayCount {
                break
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        // 最大画像数まで追加画像を読み込む
        for _ in 0 ..<
            (
                (GalleryViewModel.maxImageCount - GalleryViewModel.targetInitialDisplayCount) / GalleryViewModel
                    .batchDisplayCount
            )
        {
            let newImages = TestResources.createMockCatImageURLModels(using: Array(
                repeating: TestResources.mockURLs[0],
                count: GalleryViewModel.batchDisplayCount
            ))
            mockLoader.loadImagesWithScreeningResult = newImages
            await viewModel.fetchAdditionalImages()

            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        // 最大画像数の検証
        XCTAssertEqual(viewModel.imageURLsToShow.count, GalleryViewModel.maxImageCount, "最大画像数に達している")

        // さらに画像を追加しようとする
        let newImages = TestResources.createMockCatImageURLModels(using: Array(
            repeating: TestResources.mockURLs[0],
            count: GalleryViewModel.batchDisplayCount
        ))
        mockLoader.loadImagesWithScreeningResult = newImages
        await viewModel.fetchAdditionalImages()

        // 再読み込み用の画像を設定
        mockLoader.loadImagesWithScreeningResult = initialImages

        // 再読み込みの完了を待機
        for _ in 0 ..< 10 {
            if viewModel.imageURLsToShow.count == GalleryViewModel.targetInitialDisplayCount {
                break
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        // 再読み込みの検証
        XCTAssertEqual(
            viewModel.imageURLsToShow.count,
            GalleryViewModel.targetInitialDisplayCount,
            "画像がクリアされて再読み込みされている"
        )
        XCTAssertNil(viewModel.errorMessage, "エラーメッセージがnil")
        XCTAssertFalse(viewModel.isLoading, "ローディングが完了している")
    }
}
