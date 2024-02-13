import AppKit

class FrameDrawingView: NSView {
    var frameRect: CGRect = .zero {
        didSet {
            needsDisplay = true
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSColor.clear.set()
        dirtyRect.fill()

        let path = NSBezierPath(rect: frameRect)
        NSColor.blue.setStroke()
        path.lineWidth = 1
        path.stroke()
    }
}

class FrameWindowController: NSWindowController {
    init(contentRect: CGRect) {
        let window = NSWindow(contentRect: contentRect, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = NSColor.clear
        window.level = .floating
        window.ignoresMouseEvents = true
        
        let frameView = FrameDrawingView(frame: contentRect)
        frameView.frameRect = contentRect
        window.contentView = frameView

        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showFrame() {
        window?.makeKeyAndOrderFront(nil)
    }

    func hideFrame() {
        window?.orderOut(nil)
    }

    func updateFrame(to rect: CGRect) {
        window?.setFrame(rect, display: true)
        if let frameView = window?.contentView as? FrameDrawingView {
            frameView.frameRect = window?.contentView?.bounds ?? .zero
        }
    }
}
