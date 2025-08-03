import XCTest

@MainActor
final class CatImageGalleryUITests: XCTestCase {
    var app: XCUIApplication!
    let defaultTimeout: TimeInterval = 20

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("--uitesting")
    }

    override func tearDown() {
        app.terminate()
        super.tearDown()
    }

    // MARK: - 初期表示テスト

    func testInitialDisplay() throws {
        app.launch()

        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: defaultTimeout))

        let firstImage = app.images["galleryImage_0"]
        XCTAssertTrue(firstImage.waitForExistence(timeout: defaultTimeout))
    }

    // MARK: - リフレッシュ機能テスト

    func testRefreshButton() throws {
        app.launch()

        let refreshButton = app.buttons["refreshButton"]
        XCTAssertTrue(refreshButton.waitForExistence(timeout: defaultTimeout))

        let firstImage = app.images["galleryImage_0"]
        XCTAssertTrue(firstImage.waitForExistence(timeout: defaultTimeout))

        refreshButton.tap()

        // リフレッシュ後、最初の画像が再表示されるのを待つ
        let refreshedFirstImage = app.images["galleryImage_0"]
        XCTAssertTrue(refreshedFirstImage.waitForExistence(timeout: defaultTimeout))
    }

    // MARK: - エラー状態テスト

    func testErrorStateDisplayAndRetry() throws {
        app.launchArguments.append("--simulate-error")
        app.launch()

        let errorTitle = app.staticTexts["errorTitle"]
        XCTAssertTrue(errorTitle.waitForExistence(timeout: defaultTimeout))

        let retryButton = app.buttons["retryButton"]
        XCTAssertTrue(retryButton.exists)

        retryButton.tap()

        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: defaultTimeout))

        let firstImage = app.images["galleryImage_0"]
        XCTAssertTrue(firstImage.waitForExistence(timeout: defaultTimeout))
    }

    // MARK: - 追加取得機能テスト

    func testAdditionalFetch() throws {
        app.launch()

        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: defaultTimeout))

        let firstImage = app.images["galleryImage_0"]
        XCTAssertTrue(firstImage.waitForExistence(timeout: defaultTimeout))

        // 30枚目の画像（インデックス29）が表示されるまで下にスワイプする
        let targetImage = app.images["galleryImage_29"]

        var attempts = 0
        // isHittableがtrueになるまで、または最大試行回数に達するまでスワイプを繰り返す
        while !targetImage.isHittable && attempts < 15 {
            scrollView.swipeDown(velocity: .fast)
            attempts += 1
        }

        // 最終的に対象の画像が存在することを確認
        XCTAssertTrue(targetImage.waitForExistence(timeout: defaultTimeout))
    }
}