@testable import CatBoard
import ComposableArchitecture
import XCTest

@MainActor
final class GalleryReducerTests: XCTestCase {
    func testTask_FetchImagesSuccess_EmptyResult() async {
        // 1. 初期状態でTestStoreを初期化
        let store = TestStore(initialState: GalleryReducer.State()) {
            GalleryReducer()
        } withDependencies: {
            // 2. imageClientの依存関係をオーバーライド
            $0.imageClient.fetchImages = { _, _ in [] } // 空の配列を返す
        }

        // 3. .taskアクションを送信
        await store.send(.task)

        // 4. .fetchImagesが受信されたことを確認
        await store.receive(/GalleryAction.fetchImages) {
            $0.isLoading = true // fetchImagesが開始されると状態が変化する
            $0.errorMessage = nil
        }

        // 5. .fetchImagesResponseが空の結果で受信されたことを確認
        await store.receive(/GalleryAction.fetchImagesResponse) {
            // 6. 最終的な状態を確認
            $0.isLoading = false
            $0.items = []
        }
    }
}
