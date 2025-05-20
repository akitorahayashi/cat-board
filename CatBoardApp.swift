import ComposableArchitecture
import SwiftUI

// コメントアウトされたUIテスト用コード削除

@main
struct CatBoardApp: App {
    // アプリ全体のStoreをシンプルに初期化
    static let store = Store(initialState: CoordinatorReducer.State()) {
        CoordinatorReducer()
    }

    var body: some Scene {
        WindowGroup {
            GalleryView(
                store: CatBoardApp.store.scope(state: \.gallery, action: \.gallery)
            )
            .modelContainer(for: CatImageEntity.self)
        }
    }
}
