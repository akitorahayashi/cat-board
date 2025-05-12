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
        var items: IdentifiedArrayOf<CatImageModel> = []
        var initialLoadCompleted = false
        var errorMessage: String?
    }

    typealias Action = GalleryAction

    private enum CancelID { case fetchImages }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                if !state.initialLoadCompleted {
                    return .send(.fetchInitialImages)
                }
                return .none


            case .fetchInitialImages:
                resetStateForLoad(&state)
                return fetchImagesEffect(requestedLimit: Self.fetchLimit)

            case let .receivedImageBatch(batch):
                let newItems = batch.map { model -> CatImageModel in
                    var mutableModel = model
                    mutableModel.isLoading = false
                    return mutableModel
                }
                state.items.append(contentsOf: newItems)
                return .none

            case .fetchStreamCompleted:
                state.initialLoadCompleted = true
                print("[GalleryReducer] Fetch stream COMPLETED")
                return .none

            case let .fetchStreamFailed(error):
                state.errorMessage = error.localizedDescription
                print("[GalleryReducer] Fetch stream FAILED: \(error.localizedDescription)")
                return .none
            }
        }
    }

    private func resetStateForLoad(_ state: inout State) {
        state.items = []
        state.errorMessage = nil
        state.initialLoadCompleted = false
    }

    private func fetchImagesEffect(requestedLimit: Int) -> Effect<GalleryAction> {
        .run { send in
            let stream = await imageClient.fetchImages(requestedLimit, 0)
            do {
                for try await batch in stream {
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
