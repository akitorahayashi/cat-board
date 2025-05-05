import Foundation

/// 画像スクリーニングの結果ラベルを表す Enum
enum ScreeningLabel: String, Equatable {
    case scary = "Scary"
    case notScary = "Not Scary"
    /// 予期しないラベルや初期化に失敗した場合
    case unknown

    /// 文字列から Enum ケースを初期化（大文字小文字を区別しない）
    /// - Parameter stringValue: モデルから返されるラベル文字列
    init(stringValue: String) {
        switch stringValue.lowercased() {
        case "scary":
            self = .scary
        case "not scary":
            self = .notScary
        default:
            print("WARN: Unknown screening label received: \(stringValue)")
            self = .unknown
        }
    }
} 