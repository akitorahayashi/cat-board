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
        // ストリームから画像のバッチを受信
        case _receivedImageBatch([CatImageModel])
        // ストリーム処理が完了 (成功/失敗問わず)
        case _fetchStreamCompleted
        // ストリーム処理でエラーが発生
        case _fetchStreamFailed(Error)
    }

    // ストリーム処理を一意に識別するためのID (キャンセル可能にするため)
    private enum CancelID { case fetchImages }

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

                return fetchImagesEffect(page: state.currentPage, requestedLimit: Self.fetchLimit)

            case .loadMoreImages:
                guard state.canLoadMore, !state.isLoadingMore, !state.isLoading else { return .none }
                state.isLoadingMore = true
                let pageToFetch = state.currentPage

                return fetchImagesEffect(page: pageToFetch, requestedLimit: Self.fetchLimit)

            case .pullRefresh:
                guard !state.isLoading else { return .cancel(id: CancelID.fetchImages) }
                state.items = []
                state.currentPage = 0
                state.canLoadMore = true
                state.errorMessage = nil
                state.isLoading = true
                state.isLoadingMore = false

                return fetchImagesEffect(page: state.currentPage, requestedLimit: Self.fetchLimit)

            case let ._receivedImageBatch(batch):
                if batch.isEmpty && (state.isLoading || state.isLoadingMore) {
                    // ストリームから空のバッチが来た場合、それはもうデータがない可能性を示唆する。
                    // ただし、LiveImageClient は空のバッチを yield しない想定。
                    // ストリームが finish するまで canLoadMore の判断は保留する。
                } else {
                    let newItems = batch.map { model -> CatImageModel in
                        var mutableModel = model
                        mutableModel.isLoading = false
                        return mutableModel
                    }
                    state.items.append(contentsOf: newItems)
                    state.currentPage += 1
                }
                return .none

            case ._fetchStreamCompleted:
                state.isLoading = false
                state.isLoadingMore = false
                if state.items.count < (state.currentPage * Self.fetchLimit) && state.items.count > 0 {
                    // state.canLoadMore = false
                }
                print("[ImageRepositoryReducer] Fetch stream completed.")
                return .none

            case let ._fetchStreamFailed(error):
                state.isLoading = false
                state.isLoadingMore = false
                state.errorMessage = error.localizedDescription
                print("[ImageRepositoryReducer] Fetch stream failed: \(error.localizedDescription)")
                return .none
        }
    }

    private func fetchImagesEffect(page: Int, requestedLimit: Int) -> Effect<Action> {
        .run { send in
            let stream = await imageClient.fetchImages(requestedLimit, page)
            do {
                for try await batch in stream {
                    await send(._receivedImageBatch(batch))
                }
                await send(._fetchStreamCompleted)
            } catch {
                await send(._fetchStreamFailed(error))
            }
        }
        .cancellable(id: CancelID.fetchImages, cancelInFlight: true)
    }
}
