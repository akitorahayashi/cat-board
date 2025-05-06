import ComposableArchitecture
import Foundation
import SwiftUI

@Reducer
struct GalleryReducer {
    @ObservableState
    struct State: Equatable {
        var imageRepository = ImageRepositoryReducer.State()
        var selectedImageId: UUID?
    }

    typealias Action = GalleryAction

    var body: some Reducer<State, Action> {
        // ImageRepositoryへのスコープ
        Scope(state: \.imageRepository, action: \.imageRepository) {
            ImageRepositoryReducer()
        }

        Reduce { state, action in
            switch action {
                case .loadInitialImages:
                    // ImageRepositoryの.taskへ転送
                    return .send(.imageRepository(.loadInitialImages))

                case .imageRepository(.pullRefresh):
                    // リフレッシュ時に選択状態をリセット
                    state.selectedImageId = nil
                    return .none

                case let .imageTapped(id):
                    // 選択された画像のIDを保持
                    state.selectedImageId = id
                    return .none

                case .clearError:
                    // (エラークリア処理が必要な場合はここに実装)
                    return .none

                // 子から転送された、またはスコープによって処理されるアクションを処理
                case .imageRepository:
                    // ImageRepositoryのアクションはスコープで処理される
                    return .none
            }
        }
    }
}
