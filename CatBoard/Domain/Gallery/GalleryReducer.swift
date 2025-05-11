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
        var isLoading = false
        var isRefreshing = false
        var initialLoadCompleted = false
        var errorMessage: String?
        var selectedImageId: UUID?
    }

    typealias Action = GalleryAction

    private enum CancelID { case fetchImages }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                if !state.initialLoadCompleted && !state.isLoading {
                    return .send(.fetchInitialImages)
                }
                return .none

            case .pullRefresh:
                if !state.isRefreshing {
                     return .send(.fetchDataForRefresh)
                }
                return .none

            case let .imageTapped(id):
                state.selectedImageId = id
                return .none

            case .fetchInitialImages:
                guard !state.isLoading else { return .none }
                resetStateForLoad(&state)
                state.isLoading = true
                return fetchImagesEffect(requestedLimit: Self.fetchLimit)

            case .fetchDataForRefresh:
                guard !state.isRefreshing else { return .none } // isRefreshing でガードする方が適切かも
                resetStateForLoad(&state)
                state.isRefreshing = true
                state.isLoading = true
                return fetchImagesEffect(requestedLimit: Self.fetchLimit)

            case let .receivedImageBatch(batch):
                if state.isRefreshing { // リフレッシュ時に既存アイテムをクリアする処理はresetStateForLoadに集約
                    // state.items = [] // resetStateForLoadで行うので不要
                }
                let newItems = batch.map { model -> CatImageModel in
                    var mutableModel = model
                    mutableModel.isLoading = false
                    return mutableModel
                }
                state.items.append(contentsOf: newItems)
                return .none

            case .fetchStreamCompleted:
                if state.isLoading && !state.isRefreshing {
                    state.initialLoadCompleted = true
                }
                state.isLoading = false
                state.isRefreshing = false
                print("[GalleryReducer] Fetch stream COMPLETED (isLoading=false, isRefreshing=false)")
                return .none

            case let .fetchStreamFailed(error):
                state.isLoading = false
                state.isRefreshing = false
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
