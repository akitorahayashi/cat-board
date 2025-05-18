import XCTest
import Combine
import CBShared
import Infrastructure
@testable import CatBoard

@MainActor
final class GalleryViewModelTests: XCTestCase {
    private var viewModel: GalleryViewModel!
    private var mockImageClient: MockImageClient!
    private var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        mockImageClient = MockImageClient()
        viewModel = GalleryViewModel(imageClient: mockImageClient)
        cancellables = []
    }

    override func tearDown() {
        viewModel = nil
        mockImageClient = nil
        cancellables = nil
        super.tearDown()
    }

    // 初期状態のプロパティ値が正しいことを確認するテスト
    func testInitialState() {
        XCTAssertTrue(viewModel.catImages.isEmpty, "catImagesは初期状態で空")
        XCTAssertNil(viewModel.errorMessage, "errorMessageは初期状態でnil")
        XCTAssertFalse(viewModel.isLoading, "isLoadingは初期状態でfalse")
    }

    // onAppearが呼ばれ、catImagesが空の場合に画像を取得することを確認するテスト
    func testOnAppear_whenCatImagesIsEmpty_fetchesImages() async {
        // 前提
        let expectedImagesCount = 7 // MockImageClient はデフォルトで最大7つのダミー画像を返す
        viewModel.catImages = []

        // 検証
        let expectation = XCTestExpectation(description: "isLoading becomes false after fetching images on appear")

        var hasBeenLoading = false
        viewModel.$isLoading
            .sink { [weak self] isLoading in
                guard self != nil else { return }
                if isLoading {
                    hasBeenLoading = true
                } else if hasBeenLoading { // isLoading が true の後、false になった
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // 実行
        viewModel.onAppear()

        await fulfillment(of: [expectation], timeout: 5.0)

        // isLoadingが完了した後の最終アサーション
        XCTAssertFalse(viewModel.isLoading, "画像取得後はisLoadingがfalse")
        let currentImages = viewModel.catImages
        XCTAssertGreaterThan(currentImages.count, 0, "catImages should have loaded some images")
        XCTAssertLessThanOrEqual(currentImages.count, expectedImagesCount, "catImages count should be up to the expected count")
    }

    // onAppearが呼ばれ、catImagesが既に存在する場合に画像を取得しないことを確認するテスト
    func testOnAppear_whenCatImagesIsNotEmpty_doesNotFetchImages() {
        // 前提
        viewModel.catImages = [CatImageModel(imageURL: "url1")]

        // 実行
        viewModel.onAppear()

        // 検証
        XCTAssertEqual(viewModel.catImages.count, 1, "catImages は変更されない")
        XCTAssertEqual(viewModel.catImages.first?.imageURL, "url1", "catImages は変更されない")
    }

    // 追加の画像取得が成功することを確認するテスト
    func testFetchAdditionalImages_success() async {
        // 前提
        let expectedTotalImages = 7 // MockImageClient は一度に最大7つの画像を返す

        let expectation = XCTestExpectation(description: "isLoading becomes false after fetching additional images")

        var hasBeenLoading = false
        viewModel.$isLoading
            .sink { [weak self] isLoading in
                guard self != nil else { return }
                if isLoading {
                    hasBeenLoading = true
                } else if hasBeenLoading { // isLoading が true の後、false になった
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // 実行
        await viewModel.fetchAdditionalImages()

        // 検証 (Initial assertions)
        XCTAssertTrue(viewModel.isLoading, "画像取得開始時はisLoadingがtrue")
        XCTAssertNil(viewModel.errorMessage, "画像取得開始時はerrorMessageがnil")
        
        await fulfillment(of: [expectation], timeout: 5.0)

        // 検証 (Final assertions)
        XCTAssertFalse(viewModel.isLoading, "画像取得成功後はisLoadingがfalse")
        XCTAssertNil(viewModel.errorMessage, "画像取得成功後はerrorMessageがnil")
        
        let receivedImages = viewModel.catImages // オペレーション完了後に画像を取得
        XCTAssertNotNil(receivedImages, "画像を受信すること (receivedImages should not be nil)") // 技術的には viewModel.catImages は非オプショナル
        XCTAssertGreaterThan(receivedImages.count, 0, "MockImageClient から画像のバッチを受信すること (count > 0)")
        XCTAssertLessThanOrEqual(receivedImages.count, expectedTotalImages, "MockImageClient から画像のバッチを受信すること (count <= \\(expectedTotalImages))")
        
        receivedImages.forEach { XCTAssertFalse($0.isLoading, "モデルのisLoadingはfalse") }
        receivedImages.forEach { XCTAssertEqual($0.imageURL, "https://via.placeholder.com/120", "画像のURLはMockImageClientからのダミーURL") }
    }

    // 既に読み込み中の場合に追加の画像取得を行わないことを確認するテスト
    func testFetchAdditionalImages_whenAlreadyLoading_doesNotFetch() {
        // 前提
        viewModel.isLoading = true

        // 実行
        Task {
            await viewModel.fetchAdditionalImages()
        }

        // 検証
        XCTAssertTrue(viewModel.catImages.isEmpty, "フェッチが発生しないためcatImagesは空のまま")
        XCTAssertTrue(viewModel.isLoading, "isLoadingはtrueのまま")
    }
} 
