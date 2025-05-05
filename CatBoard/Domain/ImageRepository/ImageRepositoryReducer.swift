import ComposableArchitecture
import Foundation
import CatScreeningKit
import UIKit

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
        case internalProcessFetchedImages(TaskResult<[CatImageModel]>)
        case _updateImageState(id: CatImageModel.ID, result: TaskResult<Bool>)
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
                await send(.internalProcessFetchedImages(TaskResult { try await imageClient.fetchImages(Self.fetchLimit, 0) }))
            }

        case .loadMoreImages:
            guard state.canLoadMore, !state.isLoadingMore, !state.isLoading else { return .none }
            state.isLoadingMore = true
            let pageToFetch = state.currentPage

            return .run { [pageToFetch] send in
                await send(.internalProcessFetchedImages(TaskResult { try await imageClient.fetchImages(Self.fetchLimit, pageToFetch) }))
            }

        case let .internalProcessFetchedImages(result):
            state.isLoading = false
            state.isLoadingMore = false

            switch result {
            case let .success(newImageModels):
                state.currentPage += 1
                state.canLoadMore = !newImageModels.isEmpty
                state.errorMessage = nil

                guard !newImageModels.isEmpty else {
                    return .none
                }

                state.items.append(contentsOf: newImageModels)

                let effects = newImageModels.map { imageModel in
                    Effect.run { [id = imageModel.id] send in
                        let taskResult = await TaskResult { () -> Bool in
                            guard let screener = ScaryCatScreener() else {
                                print("Error: Failed to initialize ScaryCatScreener.")
                                return false
                            }
                            let session = URLSession(configuration: .ephemeral)

                            let urlString = imageModel.imageURL
                            guard let url = URL(string: urlString) else {
                                print("DEBUG: Invalid URL \(urlString)")
                                return false
                            }
                            do {
                                let (data, _) = try await session.data(from: url)
                                guard let uiImage = UIImage(data: data) else {
                                    print("DEBUG: Failed to create UIImage for \(url)")
                                    return false
                                }

                                let prediction = try await screener.screen(image: uiImage)
                                print("DEBUG: Screened \(urlString). Label: \(prediction.label), Confidence: \(prediction.confidence)")

                                let isSafe = prediction.label == ScreeningLabel.notScary.rawValue
                                if !isSafe {
                                     print("DEBUG: Skipping \(imageModel.id) (\(urlString)) because label is not .notScary (it was \(prediction.label)).")
                                }
                                return isSafe
                            } catch {
                                print("DEBUG: Error processing \(urlString): \(error)")
                                return false
                            }
                        }
                        await send(Action._updateImageState(id: id, result: taskResult))
                    }
                }
                return .merge(effects)

            case let .failure(error):
                state.errorMessage = error.localizedDescription
                return .none
            }

        case let ._updateImageState(id, result):
            guard let index = state.items.index(id: id) else {
                 print("DEBUG: Received update for unknown item ID: \(id)")
                 return .none
             }

             switch result {
             case .success(let isSafe):
                 if isSafe {
                     state.items[index].isLoading = false
                     print("DEBUG: Marked item \(id) as loaded (safe).")
                 } else {
                     state.items.remove(id: id)
                     print("DEBUG: Removed item \(id) (unsafe or processing error).")
                 }
             case .failure(let error):
                  print("DEBUG: Removing item \(id) due to failure: \(error.localizedDescription)")
                  state.items.remove(id: id)
             }
             return .none

        case .pullRefresh:
            state.items = []
            state.currentPage = 0
            state.canLoadMore = true
            state.errorMessage = nil
            state.isLoading = true
            state.isLoadingMore = false

            return .run { send in
                 await send(.internalProcessFetchedImages(TaskResult { try await imageClient.fetchImages(Self.fetchLimit, 0) }))
            }
        }
    }
}
