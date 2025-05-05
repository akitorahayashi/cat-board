import ComposableArchitecture

enum ImageRepositoryAction {
    case task
    case fetchImages
    case fetchImagesResponse(Result<[CatImageModel], Error>)
    case pullToRefresh
} 