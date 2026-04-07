import AppKit
import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLoginService {
    enum ToggleResult {
        case enabled
        case disabled
        case requiresApproval
    }

    private let service = SMAppService.mainApp

    var isEnabled: Bool {
        status == .enabled
    }

    var menuItemState: NSControl.StateValue {
        switch status {
        case .enabled:
            .on
        case .requiresApproval:
            .mixed
        default:
            .off
        }
    }

    var needsManualApproval: Bool {
        status == .requiresApproval
    }

    func toggle() throws -> ToggleResult {
        if isEnabled {
            try service.unregister()
            return .disabled
        }

        try service.register()

        if needsManualApproval {
            return .requiresApproval
        }

        return .enabled
    }

    private var status: SMAppService.Status {
        service.status
    }
}
