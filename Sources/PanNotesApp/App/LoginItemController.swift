import Foundation
import ServiceManagement

enum LoginItemController {
    static var isEnabled: Bool {
        let status = SMAppService.mainApp.status
        return status == .enabled || status == .requiresApproval
    }

    static var statusText: String {
        switch SMAppService.mainApp.status {
        case .enabled:
            return "Open at login enabled"
        case .notRegistered:
            return "Open at login disabled"
        case .requiresApproval:
            return "Open at login needs approval in System Settings"
        case .notFound:
            return "Open at login unavailable"
        @unknown default:
            return "Open at login status unknown"
        }
    }

    static func setEnabled(_ isEnabled: Bool) throws {
        let service = SMAppService.mainApp
        if isEnabled {
            guard service.status != .enabled && service.status != .requiresApproval else {
                return
            }
            try service.register()
        } else {
            guard service.status != .notRegistered else {
                return
            }
            try service.unregister()
        }
    }
}
