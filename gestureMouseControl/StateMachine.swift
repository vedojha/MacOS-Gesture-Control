import AVFoundation

struct HandTrackingThresholds {
    static let pinchDurationThreshold: TimeInterval = 0.5
    static let pinchDragDistanceThreshold: CGFloat = 0.1
    static let doublePinchTimeout: TimeInterval = 0.1
}

protocol HandGestureStateProtocol: AnyObject {
    var context: HandGestureContext? { get set }
    func transition() -> HandGestureStateProtocol
    func performAction()
}

class HandGestureContext {
    var handData: Hand
    var mouseEventHandler: MouseEventHandlingProtocol?

    init(handData: Hand, mouseEventHandler: MouseEventHandlingProtocol?) {
        self.handData = handData
        self.mouseEventHandler = mouseEventHandler
    }
}

class BaseHandGestureState: HandGestureStateProtocol {
    weak var context: HandGestureContext?
    
    func transition() -> HandGestureStateProtocol {
        fatalError("Transition method must be overridden")
    }
    func performAction() {
        fatalError("PerformAction method must be overridden")
    }
}


class HandGestureStateMachine {
    private var currentState: HandGestureStateProtocol
    private var context: HandGestureContext

    init(initialState: HandGestureStateProtocol, handData: Hand, mouseEventHandler: MouseEventHandlingProtocol?) {
        self.context = HandGestureContext(handData: handData, mouseEventHandler: mouseEventHandler)
        self.currentState = initialState
        self.currentState.context = self.context
    }

    func transition(handData: Hand) {
        context.handData = handData
        let nextState = currentState.transition()

        if nextState !== currentState {
            nextState.context = context
            currentState = nextState
        }
        
        currentState.performAction()
    }
}

class HoverState: BaseHandGestureState {
    override func transition() -> HandGestureStateProtocol {
        guard let handData = context?.handData else { return self }

        if handData.isDoublePinchActive {
            return DoublePinchState()
        } else if handData.isIndexPinchActive {
            return PinchState()
        } else if handData.isZoomInActive || handData.isZoomOutActive {
            // return ZoomStateMachine()
        }
        return self
    }

    override func performAction() {
        guard let handData = context?.handData, let mouseEventHandler = context?.mouseEventHandler else { return }
        mouseEventHandler.postMouseEvent(type: .mouseMoved, at: handData.screenPoint, clickState: 1)
        context?.handData.lastScreenPoint = handData.screenPoint
    }
}

class PinchState: BaseHandGestureState {
    private var pinchStartTime: Date?
    private var pinchStartPoint: CGPoint?
    private var hasPerformedAction: Bool = false

    override func transition() -> HandGestureStateProtocol {
        guard let handData = context?.handData else { return self }

        if handData.isIndexPinchActive {
            if pinchStartTime == nil {
               pinchStartTime = Date()
               pinchStartPoint = handData.screenPoint
            }
            let isAboveDurationThreshold = Date.timeElapsed(since: pinchStartTime, exceeds: HandTrackingThresholds.pinchDurationThreshold)
            let isAboveDistanceThreshold = distance(from: pinchStartPoint!, to: handData.screenPoint) >= HandTrackingThresholds.pinchDragDistanceThreshold

            if isAboveDurationThreshold && isAboveDistanceThreshold {
                if !hasPerformedAction {
                    context?.mouseEventHandler?.postMouseEvent(type: .leftMouseDown, at: handData.screenPoint, clickState: 1)
                    hasPerformedAction = true
                }
                return DragState()
            } else {
                return self
            }
        } else {
            if hasPerformedAction {
                context?.mouseEventHandler?.postMouseEvent(type: .leftMouseUp, at: handData.screenPoint, clickState: 1)
            }
            pinchStartTime = nil
            pinchStartPoint = nil
            hasPerformedAction = false
            return HoverState()
        }
    }

    override func performAction() {
        guard let handData = context?.handData, let mouseEventHandler = context?.mouseEventHandler else { return }

        if !hasPerformedAction {
            mouseEventHandler.postMouseEvent(type: .leftMouseDown, at: handData.screenPoint, clickState: 1)
            hasPerformedAction = true
        }
    }

    private func resetState() {
        pinchStartTime = nil
        pinchStartPoint = nil
        hasPerformedAction = false
    }
    
    private func distance(from start: CGPoint, to end: CGPoint) -> CGFloat {
        let deltaX = start.x - end.x
        let deltaY = start.y - end.y
        return sqrt(deltaX * deltaX + deltaY * deltaY)
    }
}

class DragState: BaseHandGestureState {
    override func transition() -> HandGestureStateProtocol {
        guard let handData = context?.handData else { return self }

        if !handData.isIndexPinchActive {
            context?.mouseEventHandler?.postMouseEvent(type: .leftMouseUp, at: handData.screenPoint, clickState: 1)
            return HoverState()
        }
        return self
    }

    override func performAction() {
        guard let handData = context?.handData, let mouseEventHandler = context?.mouseEventHandler else { return }
        mouseEventHandler.postMouseEvent(type: .leftMouseDragged, at: handData.screenPoint, clickState: 1)
    }
}

class DoublePinchState: BaseHandGestureState {
    private var doublePinchPerformed = false
    private var firstPinchTime: Date?

    override func transition() -> HandGestureStateProtocol {
        guard let handData = context?.handData else { return self }

        if handData.isDoublePinchActive {
            if firstPinchTime == nil {
                firstPinchTime = Date()
            } else if let firstTime = firstPinchTime, Date().timeIntervalSince(firstTime) <= HandTrackingThresholds.doublePinchTimeout {
                if !doublePinchPerformed {
                    context?.mouseEventHandler?.postLeftDoubleClickMouseEvent(at: handData.screenPoint)
                    doublePinchPerformed = true
                }
                return self
            }
        }

        if firstPinchTime != nil && (!handData.isDoublePinchActive || Date.timeElapsed(since: firstPinchTime, exceeds: HandTrackingThresholds.doublePinchTimeout)) {
            resetState()
            return HoverState()
        }
        return self
    }

    private func resetState() {
        firstPinchTime = nil
        doublePinchPerformed = false
    }

    override func performAction() {
        // Implement any actions specific to DoublePinchState here, if needed.
    }
}


extension Date {
    static func timeElapsed(since date: Date?, exceeds interval: TimeInterval) -> Bool {
        guard let date = date else { return true } // If date is nil, assume elapsed
        return -date.timeIntervalSinceNow > interval
    }
}

