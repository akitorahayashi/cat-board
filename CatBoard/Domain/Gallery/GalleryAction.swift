import CBShared
import ComposableArchitecture
import Foundation
import SwiftUI

@CasePathable
enum GalleryAction {
    // --- View からのユーザー操作 ---
    case onAppear
    case pullRefresh
    case imageTapped(UUID)

    // --- データ取得ライフサイクル (内部トリガー/コールバック) ---
    case fetchInitialImages
    case fetchDataForRefresh
    case receivedImageBatch([CatImageModel])
    case fetchStreamCompleted
    case fetchStreamFailed(Error)
}
