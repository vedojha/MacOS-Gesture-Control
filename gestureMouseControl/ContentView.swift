import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var viewModel = HandTrackingViewModel()
    
    var body: some View {
        CameraPreview(previewLayer: viewModel.previewLayer ?? AVCaptureVideoPreviewLayer())
            .onAppear {
                viewModel.startSession()
            }
            .onDisappear {
                viewModel.stopSession()
            }
    }
}

struct CameraPreview: NSViewRepresentable {
    var previewLayer: AVCaptureVideoPreviewLayer

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer = previewLayer
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if nsView.layer != previewLayer {
            nsView.layer = previewLayer
        }
        previewLayer.frame = nsView.bounds
    }
}
