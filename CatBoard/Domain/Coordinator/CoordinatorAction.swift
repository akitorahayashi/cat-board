import ComposableArchitecture

@CasePathable
enum CoordinatorAction {
    case gallery(GalleryAction)
}
