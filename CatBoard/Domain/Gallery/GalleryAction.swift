import ComposableArchitecture
import Foundation
import SwiftUI

@CasePathable
enum GalleryAction {
    // 子ドメインのアクション
    case imageRepository(ImageRepositoryReducer.Action)

    // ギャラリー固有のアクション
    case loadInitialImages
    case imageTapped(UUID)
    case clearError
}
