import SwiftUI
import AVFoundation
import Vision
import Combine

class CameraManager: NSObject, ObservableObject {
    @Published var previewLayer: AVCaptureVideoPreviewLayer?
    private var cameraFeedSession = AVCaptureSession()
    private let videoDataOutputQueue = DispatchQueue(label: "VideoDataOutputQueue")
    let handPosePublisher = PassthroughSubject<VNHumanHandPoseObservation, Error>()
    
    override init() {
        super.init()
        setupAVSession()
        setupPreviewLayer()
    }
    
    func setupAVSession() {
        cameraFeedSession.beginConfiguration()
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let deviceInput = try? AVCaptureDeviceInput(device: camera) else {
            fatalError("Front camera or device input setup failed.")
        }
        if cameraFeedSession.canAddInput(deviceInput) { cameraFeedSession.addInput(deviceInput) }
        let dataOutput = AVCaptureVideoDataOutput()
        dataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        if cameraFeedSession.canAddOutput(dataOutput) { cameraFeedSession.addOutput(dataOutput) }
        cameraFeedSession.commitConfiguration()
        
        if let connection = dataOutput.connection(with: .video) {
            DispatchQueue.main.async {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = true
            }
        }
    }
    
    func startSession() {
        if !cameraFeedSession.isRunning {
            cameraFeedSession.startRunning()
        }
    }
    
    func stopSession() {
        if cameraFeedSession.isRunning {
            cameraFeedSession.stopRunning()
        }
    }
    
    private func setupPreviewLayer() {
        let layer = AVCaptureVideoPreviewLayer(session: cameraFeedSession)
        layer.videoGravity = .resizeAspectFill
        layer.connection?.automaticallyAdjustsVideoMirroring = false
        layer.connection?.isVideoMirrored = true
        previewLayer = layer
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let handPoseRequest = VNDetectHumanHandPoseRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([handPoseRequest])
            if let observation = handPoseRequest.results?.first as? VNHumanHandPoseObservation {
                handPosePublisher.send(observation)
            }
        } catch {
            handPosePublisher.send(completion: .failure(error))
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
