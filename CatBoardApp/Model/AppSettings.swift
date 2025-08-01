import Foundation
import SwiftUI

class AppSettings: ObservableObject {
    @Published var isScreeningEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isScreeningEnabled, forKey: "isScreeningEnabled")
            onSettingsChanged?()
        }
    }

    @Published var scaryMode: Bool {
        didSet {
            UserDefaults.standard.set(scaryMode, forKey: "scaryMode")
            onSettingsChanged?()
        }
    }

    // Settings change callback
    var onSettingsChanged: (() -> Void)?

    init() {
        isScreeningEnabled = UserDefaults.standard.bool(forKey: "isScreeningEnabled")
        scaryMode = UserDefaults.standard.bool(forKey: "scaryMode")
    }

    // Static access for other modules
    static var shared = AppSettings()
}
