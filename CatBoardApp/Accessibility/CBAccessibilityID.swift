import Foundation

public enum CBAccessibilityID {
    public enum Gallery {
        public static let refreshButton = "refreshButton"
        public static let settingsButton = "settingsButton"

        public static func image(id: Int) -> String {
            "galleryImage_\(id)"
        }
    }

    public enum ErrorView {
        public static let title = "errorTitle"
        public static let retryButton = "retryButton"
    }
}
