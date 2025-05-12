import CBShared
import ComposableArchitecture
import Foundation
import SwiftUI

@CasePathable
enum GalleryAction {
    // --- View 操作 ---
    case onAppear

    // --- データ取得ライフサイクル (内部トリガー/コールバック) ---
    case fetchInitialImages
    case receivedImageBatch([CatImageModel])
    case fetchStreamCompleted
    case fetchStreamFailed(Error)
}
