import AVFoundation

protocol MouseEventHandlingProtocol: AnyObject {
    func postLeftSingleClickMouseEvent(at point: CGPoint)
    func postLeftDoubleClickMouseEvent(at point: CGPoint)
    func postMouseEvent(type: CGEventType, at point: CGPoint, clickState: Int)
    func postKeyEvent(virtualKey: CGKeyCode, keyDown: Bool, flags: CGEventFlags)
    func postScrollEvent(with increment: Int, at point: CGPoint, flags: CGEventFlags)
}

class MouseEventHandler: MouseEventHandlingProtocol {
    static let shared = MouseEventHandler()
    private init() {}

    func postLeftDoubleClickMouseEvent(at point: CGPoint) {
        postMouseEvent(type: .leftMouseDown, at: point, clickState: 1)
        postMouseEvent(type: .leftMouseUp, at: point, clickState: 1)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
            postMouseEvent(type: .leftMouseDown, at: point, clickState: 2)
            postMouseEvent(type: .leftMouseUp, at: point, clickState: 2)
        }
    }

    func postLeftSingleClickMouseEvent(at point: CGPoint) {
        postMouseEvent(type: .leftMouseDown, at: point, clickState: 1)
        postMouseEvent(type: .leftMouseUp, at: point, clickState: 1)
    }

    func postMouseEvent(type: CGEventType, at point: CGPoint, clickState: Int = 1) {
        guard let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: .left) else {
            NSLog("Failed to create mouse event for type: \(type.rawValue)")
            return
        }
        event.setIntegerValueField(.mouseEventClickState, value: Int64(clickState))
        postEvent(event)
    }

    func postKeyEvent(virtualKey: CGKeyCode, keyDown: Bool, flags: CGEventFlags) {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: virtualKey, keyDown: keyDown) else { return }
        event.flags = flags
        postEvent(event)
    }

    func postScrollEvent(with increment: Int, at point: CGPoint, flags: CGEventFlags) {
        guard let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1, wheel1: Int32(increment), wheel2: 0, wheel3: 0) else { return }
        event.flags = flags
        event.location = point
        postEvent(event)
    }

    private func postEvent(_ event: CGEvent) {
        event.post(tap: .cghidEventTap)
    }
}
