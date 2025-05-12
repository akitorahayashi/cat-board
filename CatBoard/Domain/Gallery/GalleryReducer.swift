import CBShared
import ComposableArchitecture
import Foundation
import SwiftUI

@Reducer
struct GalleryReducer {
    static let fetchLimit = 10

    @Dependency(\.imageClient) var imageClient

    @ObservableState
    struct State: Equatable {
        var catImages: IdentifiedArrayOf<CatImageModel> = []
        var errorMessage: String?
    }

    typealias Action = GalleryAction

    private enum CancelID { case fetchImages }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .send(GalleryAction.fetchAdditionalImages)

            case .fetchAdditionalImages:
                return .run { send in
                    let stream = await imageClient.fetchImages(
                        desiredSafeImageCountPerFetch: Self.fetchLimit,
                        timesOfFetch: 3
                    )
                    do {
                        var newItems: [CatImageModel] = []
                        for try await batch in stream {
                            newItems += batch.map { model -> CatImageModel in
                                var mutableModel = model
                                mutableModel.isLoading = false
                                return mutableModel
                            }
                        }
                        await send(.didFetchImages(newItems))
                    } catch {
                        await send(.didFailToFetchImages(error.localizedDescription))
                    }
                }
                .cancellable(id: CancelID.fetchImages, cancelInFlight: true)

            case .didFetchImages(let newItems):
                state.catImages.append(contentsOf: newItems)
                return .none

            case .didFailToFetchImages(let message):
                state.errorMessage = message
                return .none
            }
        }
    }
}
