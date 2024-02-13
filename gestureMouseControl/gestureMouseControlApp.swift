import SwiftUI
import Cocoa

@main
struct GestureMouseControlApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(ScreenRecorder.shared)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var screenRecorder: ScreenRecorder? {
        didSet {
            // Additional setup if needed
        }
    }
    private var eventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        self.screenRecorder = ScreenRecorder.shared
        startKeyEventMonitor()
    }

    func applicationWillTerminate(_ notification: Notification) {
        stopKeyEventMonitor()
        stopRecordingWithDelay()
    }

    private func startKeyEventMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains(.shift) && event.keyCode == 12 { // 12 key code for 'Q'
                self?.stopRecordingWithDelay()
            }
        }
    }

    private func stopKeyEventMonitor() {
        if let eventMonitor = eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
    }

    private func stopRecordingWithDelay() {
        let semaphore = DispatchSemaphore(value: 0)
        Task {
            do {
                try await screenRecorder?.stopRecording()
                DispatchQueue.main.async {
                    print("Stopped!")
                    semaphore.signal()
                }
            } catch {
                print("Error stopping recording: \(error)")
            }
        }
        semaphore.wait(timeout: .now() + 5)
    }
}
