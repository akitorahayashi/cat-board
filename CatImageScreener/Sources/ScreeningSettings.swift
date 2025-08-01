import Foundation
import SwiftUI

public class ScreeningSettings: ObservableObject {
    // 引数なしinit: UserDefaultsから値を取得。未設定ならデフォルト値
    public init() {
        let defaults = UserDefaults.standard
        let screeningKey = ScreeningSettings.Keys.isScreeningEnabled.rawValue
        let scaryKey = ScreeningSettings.Keys.scaryMode.rawValue

        let hasScreening = defaults.object(forKey: screeningKey) != nil
        let hasScary = defaults.object(forKey: scaryKey) != nil

        #if targetEnvironment(simulator)
            isScreeningEnabled = hasScreening ? defaults.bool(forKey: screeningKey) : false
        #else
            isScreeningEnabled = hasScreening ? defaults.bool(forKey: screeningKey) : true
        #endif
        scaryMode = hasScary ? defaults.bool(forKey: scaryKey) : false
    }

    // 引数ありinit: 明示的に値を指定
    public init(isScreeningEnabled: Bool, scaryMode: Bool) {
        self.isScreeningEnabled = isScreeningEnabled
        self.scaryMode = scaryMode
    }

    @Published public var isScreeningEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isScreeningEnabled, forKey: Keys.isScreeningEnabled.rawValue)
        }
    }

    @Published public var scaryMode: Bool {
        didSet {
            UserDefaults.standard.set(scaryMode, forKey: Keys.scaryMode.rawValue)
        }
    }

    private enum Keys: String {
        case isScreeningEnabled
        case scaryMode
    }
}
