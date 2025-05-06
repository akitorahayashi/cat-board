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
        case _handleProcessedImages(TaskResult<[CatImageModel.ID]>)
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
                
                state.items.append(contentsOf: newImageModels.map {
                    var model = $0
                    model.isLoading = true
                    return model
                })
                
                return .run { [itemsToProcess = newImageModels] send async in
                    await send(._handleProcessedImages(
                        TaskResult {
                            guard let screener = try? ScaryCatScreener() else {
                                print("[DEBUG] Screener初期化失敗")
                                throw ScaryCatScreenerError.resourceBundleNotFound
                            }

                            let downloadedImages: [(CatImageModel.ID, UIImage?)] = await withTaskGroup(of: (CatImageModel.ID, UIImage?).self) { group in
                                var results = [(CatImageModel.ID, UIImage?)]()
                                for model in itemsToProcess {
                                    group.addTask {
                                        let session = URLSession(configuration: .ephemeral)
                                        guard let url = URL(string: model.imageURL) else { return (model.id, nil) }
                                        do {
                                            let (data, _) = try await session.data(from: url)
                                            return (model.id, UIImage(data: data))
                                        } catch {
                                            print("[DEBUG] 画像ダウンロード失敗: \(model.id), URL: \(model.imageURL), Error: \(error)")
                                            return (model.id, nil)
                                        }
                                    }
                                }
                                for await result in group {
                                    results.append(result)
                                }
                                return results
                            }

                            let successfulDownloads = downloadedImages.compactMap { id, image -> (CatImageModel.ID, UIImage)? in
                                guard let image = image else { return nil }
                                return (id, image)
                            }
                            let imagesToScreen = successfulDownloads.map { $0.1 }
                            let idsForImagesToScreen = successfulDownloads.map { $0.0 }

                            print("[DEBUG] \(imagesToScreen.count)枚の画像をスクリーニング開始")
                            let safeUIImages = try await screener.screen(images: imagesToScreen, enableLogging: true)
                            print("[DEBUG] スクリーニング完了。\(safeUIImages.count)枚が安全と判定。")

                            // 現状のScaryCatScreener.screenでは安全な画像のIDを特定できないため、
                            // ダウンロードに成功した画像のIDを返す。
                            let safeIDs = idsForImagesToScreen
                             print("[DEBUG] ダウンロード成功IDリスト (暫定): \(safeIDs)")

                            let failedDownloadIDs = Set(downloadedImages.filter { $0.1 == nil }.map { $0.0 })
                            print("[DEBUG] ダウンロード失敗ID: \(failedDownloadIDs)")

                            return safeIDs
                        }
                    ))
                }

            case let .failure(error):
                state.errorMessage = error.localizedDescription
                print("[DEBUG] APIからの画像取得失敗: \(error)")
                return .none
            }

        case let ._handleProcessedImages(result):
             switch result {
             case .success(let processedIDs):
                 print("[DEBUG] 一括処理結果（成功）受信。処理対象ID: \(processedIDs)")
                 let processedIDSet = Set(processedIDs)

                 for index in state.items.indices {
                     let currentID = state.items[index].id
                     if processedIDSet.contains(currentID) {
                         state.items[index].isLoading = false
                         print("[DEBUG] 状態更新: \(currentID) をローディング完了としてマーク")
                     }
                 }

             case .failure(let error):
                 print("[DEBUG] 一括処理中にエラー発生: \(error)。今回のバッチで追加された画像を削除します。")
                 let idsToRemove = state.items.filter { $0.isLoading }.map { $0.id }
                 if !idsToRemove.isEmpty {
                     print("[DEBUG] エラー発生のため削除実行: \(idsToRemove)")
                     state.items.removeAll(where: { idsToRemove.contains($0.id) })
                 }
             }
             return .none

        case .pullRefresh:
             guard !state.isLoading else { return .none }
             state.items = []
             state.currentPage = 0
             state.canLoadMore = true
             state.errorMessage = nil
             state.isLoading = true
             state.isLoadingMore = false
             
             return .run { send async in
                 await send(.internalProcessFetchedImages(TaskResult { try await imageClient.fetchImages(Self.fetchLimit, 0) }))
             }
        }
    }
}
