import ComposableArchitecture
import Foundation

@Reducer
struct ImageRepositoryReducer {
    @ObservableState
    struct State: Equatable {
        var items: IdentifiedArrayOf<CatImageModel> = []
        var isLoading = false
        var isLoadingMore = false
        var canLoadMore = true
        var errorMessage: String?
        var currentPage = 0
    }

    typealias Action = ImageRepositoryAction

    @Dependency(\.imageClient) var imageClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                guard state.items.isEmpty else { return .none }
                state.isLoading = true
                return .run { send in
                    await send(.fetchImagesResponse(Result { try await imageClient.fetchImages(20, 0) }))
                }

            case .fetchImages:
                guard state.canLoadMore, !state.isLoadingMore else { return .none }
                state.isLoadingMore = true
                let nextPage = state.currentPage + 1
                return .run { send in
                    await send(.fetchImagesResponse(Result { try await imageClient.fetchImages(20, nextPage) }))
                }

            case let .fetchImagesResponse(.success(newImages)):
                state.isLoading = false
                state.isLoadingMore = false
                state.items.append(contentsOf: newImages)
                state.currentPage += 1
                state.canLoadMore = !newImages.isEmpty
                state.errorMessage = nil
                return .none

            case let .fetchImagesResponse(.failure(error)):
                state.isLoading = false
                state.isLoadingMore = false
                state.errorMessage = error.localizedDescription
                return .none

            case .pullToRefresh:
                state.items = []
                state.currentPage = 0
                state.canLoadMore = true
                state.errorMessage = nil
                return .run { send in
                     await send(.fetchImagesResponse(Result { try await imageClient.fetchImages(20, 0) }))
                }
            }
        }
    }
}