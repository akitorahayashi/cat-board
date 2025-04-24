import ComposableArchitecture
import Foundation

@Reducer
struct GalleryReducer {
    @Dependency(\.imageClient) var imageClient

    var body: some Reducer<GalleryState, GalleryAction> {
        Reduce { state, action in
            switch action {
                case .task:
                    // ビューが表示された際に初期データを読み込む (アイテムが空の場合など)
                    // シンプルにするため、常に読み込みを実行
                    return .send(.fetchImages)

                case .pullToRefresh:
                    // ユーザーがプルリフレッシュ操作を行った際に再度データを読み込む
                    return .send(.fetchImages)

                case .fetchImages:
                    // 画像取得中の状態に設定
                    state.isLoading = true
                    state.errorMessage = nil
                    // APIクライアントを使って画像を取得する副作用を実行
                    return .run { send in
                        await send(.fetchImagesResponse(
                            // 引数ラベルなしでfetchImagesを呼び出す
                            Result { try await imageClient.fetchImages(20, 0) as [CatImageModel] }
                        ))
                    }

                case let .fetchImagesResponse(.success(items)):
                    // 取得成功時の処理
                    state.isLoading = false
                    state.items = items
                    // ページネーションのロジックをここに追加する必要がある (例: アイテムの追加、ページ番号の更新)
                    return .none

                case let .fetchImagesResponse(.failure(error)):
                    // 取得失敗時の処理
                    state.isLoading = false
                    state.errorMessage = "データの取得中にエラーが発生しました: \(error.localizedDescription)"
                    print("取得エラー: \(error)")
                    return .none

                case .clearError:
                    // エラーメッセージをクリア
                    state.errorMessage = nil
                    return .none
            }
        }
    }
}
