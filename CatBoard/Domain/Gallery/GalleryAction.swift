import ComposableArchitecture
import Foundation

@CasePathable
enum GalleryAction {
    case task
    case pullToRefresh
    case fetchImages
    case fetchImagesResponse(Result<[CatImageModel], Error>)
    // case imageTapped(CatImageModel.ID)
    case clearError
}
