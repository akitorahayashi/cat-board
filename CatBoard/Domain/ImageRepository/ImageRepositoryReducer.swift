import CBShared
import ComposableArchitecture

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
        var isRefreshing = false
        var initialLoadCompleted = false
        var canLoadMore = true
        var errorMessage: String?
        var currentPage = 0

        var canActuallyLoadMore: Bool {
            canLoadMore && !isLoadingMore && !isLoading && initialLoadCompleted
        }
    }

    enum Action {
        case loadInitialImages
        case loadMoreImages
        case pullRefresh
        // ストリームから画像のバッチを受信
        case receivedImageBatch([CatImageModel])
        // ストリーム処理が完了 (成功/失敗問わず)
        case fetchStreamCompleted
        // ストリーム処理でエラーが発生
        case fetchStreamFailed(Error)
    }

    // ストリーム処理を一意に識別するためのID (キャンセル可能にするため)
    private enum CancelID { case fetchImages }

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
            case .loadInitialImages:
                guard !state.isLoading else { return .none }
                resetStateForLoad(&state)
                state.isLoading = true
                return fetchImagesEffect(page: state.currentPage, requestedLimit: Self.fetchLimit)

            case .loadMoreImages:
                guard state.canActuallyLoadMore else { return .none }
                state.isLoadingMore = true
                state.isLoading = true
                state.isRefreshing = false
                return fetchImagesEffect(page: state.currentPage, requestedLimit: Self.fetchLimit)

            case .pullRefresh:
                resetStateForLoad(&state)
                state.isLoading = true
                state.isRefreshing = true
                return fetchImagesEffect(page: state.currentPage, requestedLimit: Self.fetchLimit)

            case let .receivedImageBatch(batch):
                if state.isRefreshing {
                    state.items = []
                    state.isRefreshing = false
                }

                let newItems = batch.map { model -> CatImageModel in
                    var mutableModel = model
                    mutableModel.isLoading = false
                    return mutableModel
                }
                state.items.append(contentsOf: newItems)
                if !batch.isEmpty {
                    state.currentPage += 1
                }
                return .none

            case .fetchStreamCompleted:
                if !state.isLoadingMore, !state.isRefreshing, state.isLoading {
                    state.initialLoadCompleted = true
                }
                state.isLoading = false
                state.isLoadingMore = false
                state.isRefreshing = false
                print("[ImageRepositoryReducer] Fetch stream COMPLETED (isLoading=false)")
                return .none

            case let .fetchStreamFailed(error):
                state.isLoading = false
                state.isLoadingMore = false
                state.isRefreshing = false
                state.errorMessage = error.localizedDescription
                print("[ImageRepositoryReducer] Fetch stream FAILED (isLoading=false): \(error.localizedDescription)")
                return .none
        }
    }

    // Helper function to reset state for loading images
    private func resetStateForLoad(_ state: inout State) {
        state.items = []
        state.currentPage = 0
        state.canLoadMore = true
        state.errorMessage = nil
        state.isLoadingMore = false
        state.isRefreshing = false
        state.initialLoadCompleted = false
    }

    private func fetchImagesEffect(page: Int, requestedLimit: Int) -> Effect<Action> {
        .run { send in
            let stream = await imageClient.fetchImages(requestedLimit, page)
            do {
                var isEmptyStream = true
                for try await batch in stream {
                    isEmptyStream = false
                    await send(.receivedImageBatch(batch))
                }
                await send(.fetchStreamCompleted)
            } catch {
                await send(.fetchStreamFailed(error))
            }
        }
        .cancellable(id: CancelID.fetchImages, cancelInFlight: true)
    }
}
