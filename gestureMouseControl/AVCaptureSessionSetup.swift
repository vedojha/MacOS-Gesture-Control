import AVFoundation
import Vision

extension HandTrackingViewModel {
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
//        previewLayer = createPreviewLayer()
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
    
    func createPreviewLayer() -> AVCaptureVideoPreviewLayer {
        let previewLayer = AVCaptureVideoPreviewLayer(session: cameraFeedSession)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.connection?.automaticallyAdjustsVideoMirroring = false
        previewLayer.connection?.isVideoMirrored = true
        return previewLayer
    }
}

extension HandTrackingViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([handPoseRequest])
            guard let observation = handPoseRequest.results?.first as? VNHumanHandPoseObservation else { return }
            self.process(hand: observation)
        } catch {
            print("Failed to perform Vision request: \(error)")
        }
    }
}

