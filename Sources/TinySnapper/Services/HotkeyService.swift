import Carbon
import Foundation

final class HotkeyService {
    private static let signature: OSType = 0x58534E50
    private enum HotkeyID: UInt32 {
        case capture = 1
        case captureAndCopyStyled = 2
    }

    private struct HotkeyRegistration {
        let id: HotkeyID
        let keyCode: UInt32
        let modifiers: UInt32
    }

    private static let registrations: [HotkeyRegistration] = [
        HotkeyRegistration(id: .capture, keyCode: UInt32(kVK_ANSI_2), modifiers: UInt32(cmdKey | controlKey)),
        HotkeyRegistration(id: .captureAndCopyStyled, keyCode: UInt32(kVK_ANSI_2), modifiers: UInt32(cmdKey | shiftKey)),
    ]
    private static let handler: EventHandlerUPP = { _, eventRef, userData in
        guard
            let userData,
            let eventRef
        else {
            return noErr
        }

        let service = Unmanaged<HotkeyService>.fromOpaque(userData).takeUnretainedValue()
        return service.handle(event: eventRef)
    }

    private let captureAction: @MainActor @Sendable () -> Void
    private let captureAndCopyStyledAction: @MainActor @Sendable () -> Void
    private var hotKeyRefs: [EventHotKeyRef] = []
    private var eventHandlerRef: EventHandlerRef?

    init(
        captureAction: @escaping @MainActor @Sendable () -> Void,
        captureAndCopyStyledAction: @escaping @MainActor @Sendable () -> Void
    ) {
        self.captureAction = captureAction
        self.captureAndCopyStyledAction = captureAndCopyStyledAction
    }

    deinit {
        for hotKeyRef in hotKeyRefs {
            UnregisterEventHotKey(hotKeyRef)
        }
    }

    func registerHotkeys() {
        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            Self.handler,
            1,
            &eventSpec,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )

        hotKeyRefs = Self.registrations.compactMap { registration in
            var hotKeyRef: EventHotKeyRef?
            let hotKeyID = EventHotKeyID(signature: Self.signature, id: registration.id.rawValue)
            let status = RegisterEventHotKey(
                registration.keyCode,
                registration.modifiers,
                hotKeyID,
                GetApplicationEventTarget(),
                0,
                &hotKeyRef
            )
            guard status == noErr, let hotKeyRef else {
                return nil
            }
            return hotKeyRef
        }
    }

    private func handle(event: EventRef) -> OSStatus {
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )

        guard status == noErr, hotKeyID.signature == Self.signature else {
            return status
        }

        let action: (@MainActor @Sendable () -> Void)?
        switch HotkeyID(rawValue: hotKeyID.id) {
        case .capture:
            action = captureAction
        case .captureAndCopyStyled:
            action = captureAndCopyStyledAction
        case nil:
            action = nil
        }

        guard let action else {
            return status
        }

        Task { @MainActor in
            action()
        }
        return noErr
    }
}
