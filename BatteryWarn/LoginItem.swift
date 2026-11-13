import Foundation
import ServiceManagement

/// Launch at login, backed by the system's login item service
enum LoginItem {
    /// Only a real .app bundle can register itself (not the bare `swift build` binary)
    static var isAvailable: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
