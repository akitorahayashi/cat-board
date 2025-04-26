import ComposableArchitecture
import Foundation

@ObservableState
struct GalleryState: Equatable {
    var items: [CatImageModel] = []
    var isLoading = false
    var errorMessage: String?
    var canLoadMore = true
    var isLoadingMore = false
}
