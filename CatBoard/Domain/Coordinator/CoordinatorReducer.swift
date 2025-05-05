import ComposableArchitecture
import SwiftUI

@Reducer
struct CoordinatorReducer {

    @ObservableState
    struct State: Equatable {
        // 他のルートレベルの状態（例：パスナビゲーションなど）
        var gallery: GalleryReducer.State = .init()
    }

    typealias Action = CoordinatorAction

    var body: some ReducerOf<Self> {
        // Galleryドメインへのスコープ
        Scope(state: \.gallery, action: \.gallery) {
            GalleryReducer()
        }

        Reduce { _, action in
            switch action {
                // Coordinator固有のアクション処理
                case .gallery:
                    return .none
            }
        }
    }
}
