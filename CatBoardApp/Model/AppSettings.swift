import Foundation
import SwiftUI



class AppSettings: ObservableObject {
    // 引数なしinit: UserDefaultsから値を取得。未設定ならデフォルト値
    init() {
        let defaults = UserDefaults.standard
        let screeningKey = AppSettings.Keys.isScreeningEnabled.rawValue
        let scaryKey = AppSettings.Keys.scaryMode.rawValue

        let hasScreening = defaults.object(forKey: screeningKey) != nil
        let hasScary = defaults.object(forKey: scaryKey) != nil

        #if targetEnvironment(simulator)
        self.isScreeningEnabled = hasScreening ? defaults.bool(forKey: screeningKey) : false
        #else
        self.isScreeningEnabled = hasScreening ? defaults.bool(forKey: screeningKey) : true
        #endif
        self.scaryMode = hasScary ? defaults.bool(forKey: scaryKey) : false
    }

    // 引数ありinit: 明示的に値を指定
    init(isScreeningEnabled: Bool, scaryMode: Bool) {
        self.isScreeningEnabled = isScreeningEnabled
        self.scaryMode = scaryMode
    }

    @Published var isScreeningEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isScreeningEnabled, forKey: Keys.isScreeningEnabled.rawValue)
        }
    }

    @Published var scaryMode: Bool {
        didSet {
            UserDefaults.standard.set(scaryMode, forKey: Keys.scaryMode.rawValue)
        }
    }

    private enum Keys: String {
        case isScreeningEnabled
        case scaryMode
    }
}
