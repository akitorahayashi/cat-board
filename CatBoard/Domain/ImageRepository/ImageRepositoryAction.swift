import CBShared
import ComposableArchitecture

enum ImageRepositoryAction {
    // ViewのAction
    case loadInitialImages
    case loadMoreImages
    case pullRefresh

    // APIレスポンス処理（スクリーニング開始）
    case internalProcessFetchedImages(Result<[CatImageModel], Error>)

    // スクリーニング済み画像での状態更新
    case updateStateWithScreenedImages(originalCount: Int, screenedImages: [CatImageModel])
}
