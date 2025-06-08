import XCTest

@MainActor
final class CatImageGalleryUITests: XCTestCase {
    var app: XCUIApplication!

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

    func testInitialDisplay() async throws {
        app.launch()

        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.exists)

        let firstImage = app.images["galleryImage_0"]
        XCTAssertTrue(firstImage.waitForExistence(timeout: 0.02))
    }

    // MARK: - リフレッシュ機能テスト

    func testRefreshButton() async throws {
        app.launch()
        try await Task.sleep(nanoseconds: 20_000_000)

        let refreshButton = app.buttons["refreshButton"]
        XCTAssertTrue(refreshButton.waitForExistence(timeout: 0.05))

        let firstImage = app.images["galleryImage_0"]
        XCTAssertTrue(firstImage.waitForExistence(timeout: 0.02))

        refreshButton.tap()
        try await Task.sleep(nanoseconds: 20_000_000)

        let refreshExists = firstImage.waitForExistence(timeout: 0.02)
        XCTAssertTrue(refreshExists)

        let errorTitle = app.staticTexts["errorTitle"]
        let errorExists = errorTitle.exists
        XCTAssertFalse(errorExists)
    }

    // MARK: - エラー状態テスト

    func testErrorStateDisplayAndRetry() async throws {
        app.launchArguments.append("--simulate-error")
        app.launch()

        let errorTitle = app.staticTexts["errorTitle"]
        XCTAssertTrue(errorTitle.waitForExistence(timeout: 0.02))

        let retryButton = app.buttons["retryButton"]
        let retryExists = retryButton.exists
        XCTAssertTrue(retryExists)

        retryButton.tap()
        try await Task.sleep(nanoseconds: 20_000_000)

        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 0.05))

        let firstImage = app.images["galleryImage_0"]
        XCTAssertTrue(firstImage.waitForExistence(timeout: 0.02))
    }

    // MARK: - 追加取得機能テスト

    func testAdditionalFetch() async throws {
        app.launch()

        let scrollView = app.scrollViews.firstMatch
        let scrollExists = scrollView.exists
        XCTAssertTrue(scrollExists)

        let firstImage = app.images["galleryImage_0"]
        let firstExists = firstImage.waitForExistence(timeout: 0.02)
        XCTAssertTrue(firstExists)

        func getMaxImageIndex() -> Int {
            let allImages = app.images.allElementsBoundByIndex
            let regex: NSRegularExpression
            do {
                regex = try NSRegularExpression(pattern: "galleryImage_(\\d+)")
            } catch {
                XCTFail("正規表現の作成に失敗しました: \(error)")
                return -1
            }
            var maxIndex = -1

            for image in allImages {
                let identifier = image.identifier
                if let match = regex.firstMatch(in: identifier, range: NSRange(location: 0, length: identifier.count)) {
                    if let range = Range(match.range(at: 1), in: identifier) {
                        if let index = Int(identifier[range]) {
                            maxIndex = max(maxIndex, index)
                        }
                    }
                }
            }
            return maxIndex
        }

        let initialMaxIndex = getMaxImageIndex()
        XCTAssertGreaterThan(initialMaxIndex, -1)

        for _ in 0 ..< 5 {
            scrollView.swipeDown(velocity: XCUIGestureVelocity.fast)
        }

        let finalMaxIndex = getMaxImageIndex()
        XCTAssertGreaterThanOrEqual(finalMaxIndex + 1, 30)
    }
}
