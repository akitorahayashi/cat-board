import ComposableArchitecture
import Foundation
import SwiftUI

@CasePathable
enum GalleryAction {
    // 子ドメインのアクション
    case imageRepository(ImageRepositoryAction)

    // ギャラリー固有のアクション
    case task
    case imageTapped(UUID)
    case clearError
}
