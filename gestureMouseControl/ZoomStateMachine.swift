import Foundation
import CoreGraphics

enum ZoomGestureState {
    case idle, zoomIn, zoomOut
}

struct Constants {
    static let zoomInThreshold: CGFloat = 1.0
    static let zoomOutThreshold: CGFloat = 0.0
    static let normalizationOffset: CGFloat = 0.1
    static let normalizationDivisor: CGFloat = 0.15
    static let zoomFactor: CGFloat = 20000
    static let debounceThreshold: TimeInterval = 0.2
    static let optionKeyVirtualCode: CGKeyCode = 0x3A
}


class ZoomStateMachine: BaseHandGestureState {
    private var zoomGestureState: ZoomGestureState = .idle
    private var lastZoomActionTime: Date?
    private var currentZoomAverageDistance: CGFloat = 0.0
    private var lastZoomDistance: CGFloat = 0.0

     func transition(for hand: Hand) -> HandGestureStateProtocol {
//        let zoomState = handleZoomGestureChange(using: hand)
//        
//        switch zoomState {
//        case .zoomIn, .zoomOut:
//            return self
//        case .idle:
//            return HoverState(mouseEventHandler: mouseEventHandler, initialScreenPoint: hand.screenPoint)
//        }
         return self
    }

    func performAction(with handData: Hand) {
        if zoomGestureState == .zoomIn || zoomGestureState == .zoomOut {
            performZoomAction(zoomGestureState, with: handData)
        }
    }
}


extension ZoomStateMachine {
    private func handleZoomGestureChange(using handData: Hand) -> ZoomGestureState {
        guard Date().timeIntervalSince(lastZoomActionTime ?? Date()) > Constants.debounceThreshold else {
            return zoomGestureState
        }
        
        currentZoomAverageDistance = calculateAverageDistance(from: [handData.distances[0], handData.distances[1], handData.distances[2]])
        let zoomState = determineZoomState(using: handData)
             
        switch zoomState {
        case .zoomIn, .zoomOut:
            lastZoomActionTime = Date()
            performZoomAction(zoomState, with: handData)
        case .idle:
            resetZoomStateIfNeeded()
        }
        
        return zoomState
    }
    
    private func resetZoomStateIfNeeded() {
        guard zoomGestureState != .idle else { return }
        zoomGestureState = .idle
        lastZoomDistance = 0.0
    }

    private func determineZoomState(using handData: Hand) -> ZoomGestureState {
        let normalizedDistance = normalize(distance: currentZoomAverageDistance)
        // Adjust the threshold logic
        if handData.isZoomInActive && normalizedDistance > Constants.zoomInThreshold {
            return .zoomIn
        } else if handData.isZoomOutActive && normalizedDistance < Constants.zoomOutThreshold + Constants.normalizationOffset {
            return .zoomOut
        }
        return .idle
    }
    
    private func performZoomAction(_ action: ZoomGestureState, with handData: Hand) {
        if zoomGestureState != action {
            zoomGestureState = action
            lastZoomDistance = normalize(distance: currentZoomAverageDistance)
            return
        }

        let zoomIncrement = calculateZoomIncrement(for: action)
        if zoomIncrement != 0 {
            applyZoomAction(zoomIncrement: zoomIncrement, at: handData.screenPoint)
        }
        lastZoomDistance = normalize(distance: currentZoomAverageDistance)
    }

    private func calculateZoomIncrement(for action: ZoomGestureState) -> Int {
        let normalizedDistance = normalize(distance: currentZoomAverageDistance)
        var zoomIncrement = Int((normalizedDistance - lastZoomDistance) * Constants.zoomFactor)
        zoomIncrement *= (action == .zoomOut ? -1 : 1)
        return zoomIncrement
    }
    
    private func applyZoomAction(zoomIncrement: Int, at screenPoint: CGPoint) {
        let optionFlag: CGEventFlags = .maskAlternate
//        mouseEventHandler?.postKeyEvent(virtualKey: Constants.optionKeyVirtualCode, keyDown: true, flags: optionFlag)
//        mouseEventHandler?.postScrollEvent(with: -zoomIncrement, at: screenPoint, flags: optionFlag)
//        mouseEventHandler?.postKeyEvent(virtualKey: Constants.optionKeyVirtualCode, keyDown: false, flags: optionFlag)
    }
    
    private func normalize(distance: CGFloat) -> CGFloat {
        let normalized = (distance - Constants.normalizationOffset) / (Constants.normalizationDivisor - Constants.normalizationOffset)
        return max(0, min(1, normalized))
    }

    private func calculateAverageDistance(from distances: [CGFloat]) -> CGFloat {
        return distances.reduce(0, +) / CGFloat(distances.count)
    }
}
