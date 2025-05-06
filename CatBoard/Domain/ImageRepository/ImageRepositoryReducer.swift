import ComposableArchitecture
import CBShared

@Reducer
struct ImageRepositoryReducer {
    // Define a constant for the fetch limit
    static let fetchLimit = 10

    @Dependency(\.imageClient) var imageClient

    @ObservableState
    struct State: Equatable {
        var items: IdentifiedArrayOf<CatImageModel> = []
        var isLoading = false
        var isLoadingMore = false
        var canLoadMore = true
        var errorMessage: String?
        var currentPage = 0
    }

    enum Action {
        case loadInitialImages
        case loadMoreImages
        case pullRefresh
        // imageClient.fetchImages がスクリーニング済みの安全な (はずの) CatImageModel の配列を返す
        case internalProcessFetchedImages(TaskResult<[CatImageModel]>)
        // _handleProcessedImages アクションは不要になるため削除
    }

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
            case .loadInitialImages:
                guard !state.isLoading else { return .none }
                state.items = []
                state.currentPage = 0
                state.canLoadMore = true
                state.errorMessage = nil
                state.isLoading = true
                state.isLoadingMore = false

                return .run { (send: Send<Action>) in
                    // imageClient.fetchImages がスクリーニングとフィルタリングを行う
                    await send(.internalProcessFetchedImages(TaskResult { try await imageClient.fetchImages(
                        Self.fetchLimit,
                        0
                    ) }))
                }

            case .loadMoreImages:
                guard state.canLoadMore, !state.isLoadingMore, !state.isLoading else { return .none }
                state.isLoadingMore = true
                let pageToFetch = state.currentPage

                return .run { [pageToFetch] send async in
                    // imageClient.fetchImages がスクリーニングとフィルタリングを行う
                    await send(.internalProcessFetchedImages(TaskResult { try await imageClient.fetchImages(
                        Self.fetchLimit,
                        pageToFetch
                    ) }))
                }

            case let .internalProcessFetchedImages(result):
                state.isLoading = false
                state.isLoadingMore = false

                switch result {
                    case let .success(fetchedImageModels): // ImageClientから返されるのは処理済みのモデルのはず
                        state.currentPage += 1
                        state.canLoadMore = !fetchedImageModels.isEmpty
                        state.errorMessage = nil

                        guard !fetchedImageModels.isEmpty else {
                            // 新しい画像がなかった場合
                            return .none
                        }

                        // ImageClientから返されたモデルをリストに追加
                        // isLoadingフラグはImageClient側で適切に設定されているか、ここでfalseに設定
                        state.items.append(contentsOf: fetchedImageModels.map { model in
                            var mutableModel = model
                            mutableModel.isLoading = false // ここで明示的にfalseにする
                            return mutableModel
                        })
                        return .none

                    case let .failure(error):
                        state.errorMessage = error.localizedDescription
                        return .none
                }

            case .pullRefresh:
                guard !state.isLoading else { return .none }
                state.items = []
                state.currentPage = 0
                state.canLoadMore = true
                state.errorMessage = nil
                state.isLoading = true
                state.isLoadingMore = false

                return .run { send async in
                    await send(.internalProcessFetchedImages(TaskResult { try await imageClient.fetchImages(
                        Self.fetchLimit,
                        0
                    ) }))
                }
        }
    }
}
