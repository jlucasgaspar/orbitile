import AppKit
import CoreGraphics

// Private WindowServer calls: let a background app set the cursor (the overlay never takes focus).
@_silgen_name("CGSMainConnectionID") private func CGSMainConnectionID() -> Int32
@_silgen_name("CGSSetConnectionProperty")
private func CGSSetConnectionProperty(_ cid: Int32, _ target: Int32, _ key: CFString, _ value: CFTypeRef) -> Int32

/// Global tap for the middle button (click to open, click again to confirm) and Esc.
/// Events are swallowed only while a gesture owns them; otherwise they pass through.
@MainActor
final class MouseTap {
    private static let middleButton: Int64 = 2
    private static let escapeKey: Int64 = 53

    /// Main row and keypad 2 / 4 / 6 / 8 / 0 (for 10) -> family index.
    private static let familyKeys: [Int64: Int] = [
        19: 0, 21: 1, 22: 2, 28: 3, 29: 4,
        84: 0, 86: 1, 88: 2, 91: 3, 82: 4,
    ]

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var session: GestureSession?
    /// The button-up of a click that opened/closed a gesture must not reach other apps.
    private var swallowMiddleUp = false
    private var swallowLeftUp = false

    var isRunning: Bool { tap != nil }

    /// When off, every event passes through untouched and an open overlay closes without applying.
    var isEnabled = true {
        didSet {
            guard !isEnabled, let s = session else { return }
            session = nil
            s.finish(apply: false)
        }
    }

    func start() -> Bool {
        if isRunning { return true }
        let cid = CGSMainConnectionID()
        _ = CGSSetConnectionProperty(cid, cid, "SetsCursorInBackground" as CFString, kCFBooleanTrue)
        let types: [CGEventType] = [.otherMouseDown, .otherMouseUp, .otherMouseDragged, .mouseMoved, .leftMouseDown, .leftMouseUp, .leftMouseDragged, .keyDown]
        let mask = types.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            let me = Unmanaged<MouseTap>.fromOpaque(refcon!).takeUnretainedValue()
            let swallow = MainActor.assumeIsolated { me.handle(type, event) }
            return swallow ? nil : Unmanaged.passUnretained(event)
        }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: mask, callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()) else {
            Log.app.error("CGEvent.tapCreate returned nil (Input Monitoring or Accessibility missing)")
            return false
        }
        Log.app.notice("event tap created")
        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        self.source = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    /// Removes the tap (for example when Accessibility is revoked). `start()` can create it again.
    func stop() {
        if let s = session {
            session = nil
            s.finish(apply: false)
        }
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
    }

    /// Returns true when the event must not reach other apps.
    private func handle(_ type: CGEventType, _ event: CGEvent) -> Bool {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return false
        }
        guard isEnabled else { return false }

        switch type {

        case .otherMouseDown where isMiddle(event):
            // Second middle click confirms (or cancels when no cell is hovered).
            if let s = session {
                session = nil
                swallowMiddleUp = true
                s.update(to: event.location)
                s.finish(apply: true)
                return true
            }
            // Capture first, overlay second: the session grabs the window in its init.
            guard let s = GestureSession(startingAt: event.location) else {
                Log.app.notice("middle click ignored: no movable window under the cursor")
                return false
            }
            session = s
            swallowMiddleUp = true
            return true

        case .mouseMoved, .otherMouseDragged, .leftMouseDragged:
            guard let session else { return false }
            session.update(to: event.location)
            // Swallowed: the app underneath must not swap the cursor back to its own (I-beam, etc.).
            return type != .leftMouseDragged

        case .leftMouseDown:
            // Click a cell (or drag across cells to merge). Outside the disc cancels.
            guard let s = session else { return false }
            swallowLeftUp = true
            if s.press(at: event.location) == .cancel {
                session = nil
                s.finish(apply: false)
            }
            return true

        case .otherMouseUp where isMiddle(event):
            if swallowMiddleUp { swallowMiddleUp = false; return true }
            return session != nil

        case .leftMouseUp:
            guard swallowLeftUp else { return false }
            swallowLeftUp = false
            if let s = session, s.isDragging, s.release(at: event.location) { session = nil }
            return true

        case .keyDown:
            guard let s = session else { return false }
            let code = event.getIntegerValueField(.keyboardEventKeycode)
            if code == Self.escapeKey {
                session = nil
                s.finish(apply: false)
                return true
            }
            guard let family = Self.familyKeys[code] else { return false }
            s.selectFamily(family)
            return true

        default:
            return false
        }
    }

    private func isMiddle(_ event: CGEvent) -> Bool {
        event.getIntegerValueField(.mouseEventButtonNumber) == Self.middleButton
    }
}
