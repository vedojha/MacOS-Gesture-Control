import AVFoundation
import Combine

struct HandTrackingThresholds {
    static let pinchDurationThreshold: TimeInterval = 0.25
    static let pinchDragDistanceThreshold: CGFloat = 0.1
    static let doublePinchTimeout: TimeInterval = 0.1
}

protocol HandGestureStateProtocol: AnyObject {
    var context: HandGestureContext? { get set }
    func transition() -> HandGestureStateProtocol
    func performAction()
}

class HandGestureContext {
    @Published var handData: Hand
    var mouseEventHandler: MouseEventHandlingProtocol?
    let drvClient = SerialPortManager(hostname: "localhost", port: 9999)
    
    init(handData: Hand, mouseEventHandler: MouseEventHandlingProtocol?) {
        self.handData = handData
        self.mouseEventHandler = mouseEventHandler
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

class HoverState: HandGestureStateProtocol {
    weak var context: HandGestureContext?
    
    func transition() -> HandGestureStateProtocol {
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

    func performAction() {
        guard let handData = context?.handData, let mouseEventHandler = context?.mouseEventHandler else { return }
        mouseEventHandler.postMouseEvent(type: .mouseMoved, at: handData.screenPoint, clickState: 1)
        context?.handData.lastScreenPoint = handData.screenPoint
    }
}

class PinchState: HandGestureStateProtocol {
    weak var context: HandGestureContext?
    private var pinchStartTime: Date?
    private var pinchStartPoint: CGPoint?
    private var hasPerformedAction: Bool = false

    func transition() -> HandGestureStateProtocol {
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
                context?.drvClient.send(integer: DRVConstants.shortSingleClick80)
                context?.mouseEventHandler?.postMouseEvent(type: .leftMouseUp, at: handData.screenPoint, clickState: 1)
            }
            pinchStartTime = nil
            pinchStartPoint = nil
            hasPerformedAction = false
            return HoverState()
        }
    }

    func performAction() {
        guard let handData = context?.handData, let mouseEventHandler = context?.mouseEventHandler else { return }

        if !hasPerformedAction {
            mouseEventHandler.postMouseEvent(type: .leftMouseDown, at: handData.screenPoint, clickState: 1)
            hasPerformedAction = true
        }
    }
    
    private func distance(from start: CGPoint, to end: CGPoint) -> CGFloat {
        let deltaX = start.x - end.x
        let deltaY = start.y - end.y
        return sqrt(deltaX * deltaX + deltaY * deltaY)
    }
}

class DragState: HandGestureStateProtocol {
    weak var context: HandGestureContext?
    func transition() -> HandGestureStateProtocol {
        guard let handData = context?.handData else { return self }

        if !handData.isIndexPinchActive {
            context?.mouseEventHandler?.postMouseEvent(type: .leftMouseUp, at: handData.screenPoint, clickState: 1)
            return HoverState()
        }
        return self
    }

    func performAction() {
        guard let handData = context?.handData, let mouseEventHandler = context?.mouseEventHandler else { return }
        mouseEventHandler.postMouseEvent(type: .leftMouseDragged, at: handData.screenPoint, clickState: 1)
    }
}

class DoublePinchState: HandGestureStateProtocol {
    weak var context: HandGestureContext?
    private var doublePinchPerformed = false
    private var firstPinchTime: Date?

    func transition() -> HandGestureStateProtocol {
        guard let handData = context?.handData else { return self }

        if handData.isDoublePinchActive {
            if firstPinchTime == nil {
                firstPinchTime = Date()
            } else if let firstTime = firstPinchTime, Date().timeIntervalSince(firstTime) <= HandTrackingThresholds.doublePinchTimeout {
                if !doublePinchPerformed {
                    context?.drvClient.send(integer: DRVConstants.shortDoubleClick80)
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

    func performAction() {
        
    }
}


extension Date {
    static func timeElapsed(since date: Date?, exceeds interval: TimeInterval) -> Bool {
        guard let date = date else { return true } // If date is nil, assume elapsed
        return -date.timeIntervalSinceNow > interval
    }
}

