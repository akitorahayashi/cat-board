import CBShared
import ComposableArchitecture
import Foundation
import SwiftUI

@CasePathable
enum GalleryAction {
    // --- View 操作 ---
    case onAppear

    // --- データ取得に関して内部で発行するAction ---
    case fetchAdditionalImages
    case didFetchImages([CatImageModel])
    case didFailToFetchImages(String)
}
