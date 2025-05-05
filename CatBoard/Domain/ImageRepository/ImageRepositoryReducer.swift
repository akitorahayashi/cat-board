import ComposableArchitecture
import Foundation
import CatScreeningKit
import UIKit

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

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .loadInitialImages:
            guard state.items.isEmpty else { return .none }
            state.isLoading = true
            return .run { send in
                await send(.internalProcessFetchedImages(Result { try await imageClient.fetchImages(20, 0) }))
            }

        case .loadMoreImages:
            guard state.canLoadMore, !state.isLoadingMore else { return .none }
            state.isLoadingMore = true
            let nextPage = state.currentPage + 1
            return .run { send in
                await send(.internalProcessFetchedImages(Result { try await imageClient.fetchImages(20, nextPage) }))
            }

        case let .internalProcessFetchedImages(result):
            switch result {
            case let .success(newImages):
                return .run { send in
                    guard let screener = ScaryCatScreener() else {
                        print("Error: Failed to initialize ScaryCatScreener.")
                        await send(.updateStateWithScreenedImages(originalCount: newImages.count, screenedImages: []))
                        return
                    }

                    var safeImages: [CatImageModel] = []
                    let session = URLSession(configuration: .ephemeral)

                    for imageModel in newImages {
                        let urlString = imageModel.imageURL
                        guard let url = URL(string: urlString) else { continue }

                        do {
                            let (data, _) = try await session.data(from: url)
                            guard let uiImage = UIImage(data: data) else {
                                print("Failed to create UIImage for \(url)")
                                continue
                            }

                            let prediction = try await screener.screen(image: uiImage)

                            if !prediction.label.lowercased().contains("scary") {
                                safeImages.append(imageModel)
                            }
                        } catch {
                            print("Unexpected error during download/screening for \(url): \(error)")
                        }
                    }
                    await send(.updateStateWithScreenedImages(originalCount: newImages.count, screenedImages: safeImages))
                }

            case let .failure(error):
                state.isLoading = false
                state.isLoadingMore = false
                state.errorMessage = error.localizedDescription
                return .none
            }

        case let .updateStateWithScreenedImages(originalCount, screenedImages):
            state.isLoading = false
            state.isLoadingMore = false
            state.items.append(contentsOf: screenedImages)
            state.currentPage += 1
            state.canLoadMore = originalCount > 0
            state.errorMessage = nil
            return .none

        case .pullRefresh:
            state.items = []
            state.currentPage = 0
            state.canLoadMore = true
            state.errorMessage = nil
            state.isLoading = true
            return .run { send in
                 await send(.internalProcessFetchedImages(Result { try await imageClient.fetchImages(20, 0) }))
            }
        }
    }
}
