import ComposableArchitecture
import SwiftUI

@ObservableState
struct CoordinatorState: Equatable {
    // 他のルートレベルの状態（例：パスナビゲーションなど）があればここに追加
    var gallery: GalleryState = .init()
}
