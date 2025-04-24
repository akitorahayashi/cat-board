import ComposableArchitecture

@Reducer
struct CoordinatorReducer {
    typealias State = CoordinatorState
    typealias Action = CoordinatorAction

    // MARK: - Reducer Body

    var body: some ReducerOf<Self> {
        Scope(state: \.gallery, action: \.gallery) {
            GalleryReducer()
        }

        Reduce { _, action in
            switch action {
                case .gallery:
                    return .none
            }
        }
    }
}
