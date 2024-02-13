import SwiftUI
import AVFoundation
import ScreenCaptureKit

struct CapturedFrame {
    let surface: IOSurface
    let contentRect: CGRect
    let contentScale: CGFloat
    let scaleFactor: CGFloat
}

class ScreenRecorder: NSObject, SCStreamDelegate, ObservableObject, SCStreamOutput {
    private var stream: SCStream?
    private let videoSampleBufferQueue = DispatchQueue(label: "com.yourdomain.ScreenRecorder.videoSampleBufferQueue")
    private var frameWindowController: FrameWindowController?
    static let shared = ScreenRecorder(isAudioCaptureEnabled: false, isAppAudioExcluded: false)
    private var scaleFactor: Int
    private var assetWriter: AVAssetWriter?
    private var videoWriterInput: AVAssetWriterInput?
    private var isRecording = false
    private var isAppAudioExcluded: Bool = false
    private var firstFrameTime: CMTime?
    private var lastFrame: CMSampleBuffer?
    private var firstFrameDimensions: CGSize?

    private init(isAudioCaptureEnabled: Bool, isAppAudioExcluded: Bool, scaleFactor: Int = 4) {
        self.scaleFactor = scaleFactor
        super.init()
    }

    func startCapturing() async throws {
        let availableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = availableContent.displays.first else {
            throw NSError(domain: "ScreenCaptureError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No available displays found."])
        }
        let excludedApps = isAppAudioExcluded ? availableContent.applications.filter { $0.bundleIdentifier == Bundle.main.bundleIdentifier } : []

        let filter = SCContentFilter(display: display, excludingApplications: excludedApps, exceptingWindows: [])
        let streamConfig = SCStreamConfiguration()
        streamConfig.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        streamConfig.queueDepth = 5

        streamConfig.width = display.width * scaleFactor
        streamConfig.height = display.height * scaleFactor

        stream = SCStream(filter: filter, configuration: streamConfig, delegate: self)
        try stream?.addStreamOutput(self, type: .screen, sampleHandlerQueue: videoSampleBufferQueue)
        try await stream?.startCapture()
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
        guard sampleBuffer.isValid else { return }

        switch outputType {
        case .screen:
            processScreenContent(sampleBuffer)
        case .audio:
            print("Audio!")
        @unknown default:
            break
        }
    }

    private func processScreenContent(_ sampleBuffer: CMSampleBuffer) {
        guard let attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let attachments = attachmentsArray.first,
              let status = getStatus(from: attachments),
              status == .complete,
              let frame = getCapturedFrame(from: attachments, with: sampleBuffer) else { return }
        
        if firstFrameDimensions == nil {
            firstFrameDimensions = CGSize(width: frame.contentRect.width, height: frame.contentRect.height)
        }
        DispatchQueue.main.async {
           self.updateFrameWindowController(with: frame)
        }
        if firstFrameTime == nil {
            firstFrameTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        }
        if let firstFrameTime = firstFrameTime {
            let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            let adjustedTimestamp = CMTimeSubtract(timestamp, firstFrameTime)

            var adjustedSampleBuffer: CMSampleBuffer?
            var timingInfo = CMSampleTimingInfo(duration: CMSampleBufferGetDuration(sampleBuffer), presentationTimeStamp: adjustedTimestamp, decodeTimeStamp: CMSampleBufferGetDecodeTimeStamp(sampleBuffer))
            CMSampleBufferCreateCopyWithNewTiming(allocator: nil, sampleBuffer: sampleBuffer, sampleTimingEntryCount: 1, sampleTimingArray: &timingInfo, sampleBufferOut: &adjustedSampleBuffer)

            if let adjustedSampleBuffer = adjustedSampleBuffer, isRecording, videoWriterInput?.isReadyForMoreMediaData == true {
                videoWriterInput?.append(adjustedSampleBuffer)
            }
        }
        lastFrame = sampleBuffer
    }

    private func getCapturedFrame(from attachments: [SCStreamFrameInfo: Any], with sampleBuffer: CMSampleBuffer) ->     CapturedFrame? {
        guard let pixelBuffer = sampleBuffer.imageBuffer, // use for image processing 
              let surfaceRef = CVPixelBufferGetIOSurface(pixelBuffer)?.takeUnretainedValue(),
              let contentRect = getContentRect(from: attachments),
              let contentScale = attachments[.contentScale] as? CGFloat,
              let scaleFactor = attachments[.scaleFactor] as? CGFloat else { return nil }

        let surface = unsafeBitCast(surfaceRef, to: IOSurface.self)

        return CapturedFrame(surface: surface,
                             contentRect: contentRect,
                             contentScale: contentScale,
                             scaleFactor: scaleFactor)
    }

    private func updateFrameWindowController(with frame: CapturedFrame) {
        let screenContentRect = convertContentRectToScreenCoordinates(frame.contentRect, scaleFactor: frame.scaleFactor)

        if frameWindowController == nil {
            frameWindowController = FrameWindowController(contentRect: screenContentRect)
        } else {
            frameWindowController?.updateFrame(to: screenContentRect)
        }
        frameWindowController?.showFrame()
    }
    
    private func getContentRect(from attachments: [SCStreamFrameInfo: Any]) -> CGRect? {
        guard let contentRectDict = attachments[.contentRect] as? [String: Any],
              let x = contentRectDict["X"] as? CGFloat,
              let y = contentRectDict["Y"] as? CGFloat,
              let width = contentRectDict["Width"] as? CGFloat,
              let height = contentRectDict["Height"] as? CGFloat else { return nil }
        return CGRect(x: x, y: y, width: width, height: height)
    }
    
    private func convertContentRectToScreenCoordinates(_ contentRect: CGRect, scaleFactor: CGFloat) -> CGRect {
        let screenScaleFactor = CGFloat(scaleFactor)
        return CGRect(x: contentRect.origin.x / screenScaleFactor,
                      y: contentRect.origin.y / screenScaleFactor,
                      width: contentRect.size.width / screenScaleFactor,
                      height: contentRect.size.height / screenScaleFactor)
    }
    
    private func getStatus(from attachments: [SCStreamFrameInfo: Any]) -> SCFrameStatus? {
        guard let statusRawValue = attachments[SCStreamFrameInfo.status] as? Int else { return nil }
        return SCFrameStatus(rawValue: statusRawValue)
    }
    
    func stopCapturing() {
        stream?.stopCapture()
    }
}


extension ScreenRecorder {
    private func setupAssetWriter(outputURL: URL) throws {
        guard let dimensions = firstFrameDimensions else {
            throw NSError(domain: "ScreenRecorderError", code: -1, userInfo: [NSLocalizedDescriptionKey: "First frame dimensions are not available."])
        }
        assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mov)
        
        let colorProperties: [String: Any] = [
            AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
            AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
            AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2
        ]
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: dimensions.width, // 3456
            AVVideoHeightKey: dimensions.height, // 2234
            AVVideoColorPropertiesKey: colorProperties
        ]

        videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoWriterInput?.expectsMediaDataInRealTime = true
    }
    
    func startRecording() async throws {
        try await startCapturing()
        while firstFrameDimensions == nil {
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        let outputURL = try prepareRecordingDirectoryAndFilename()
        try setupAssetWriter(outputURL: outputURL)

        guard let unwrappedAssetWriter = assetWriter else {
            throw NSError(domain: "ScreenRecorderError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Asset writer is nil."])
        }
        guard let videoInput = self.videoWriterInput, unwrappedAssetWriter.canAdd(videoInput) else {
            throw NSError(domain: "ScreenRecorderError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to add video input to asset writer."])
        }
        unwrappedAssetWriter.add(videoInput)
        if unwrappedAssetWriter.status == .unknown {
            unwrappedAssetWriter.startWriting()
        }
        if unwrappedAssetWriter.status == .writing {
            unwrappedAssetWriter.startSession(atSourceTime: .zero)
            isRecording = true
        } else {
            throw NSError(domain: "ScreenRecorderError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Asset writer is not ready to start session."])
        }
    }

    func stopRecording() async throws {
        guard let assetWriter = assetWriter, assetWriter.status == .writing else {
            print("Asset writer is not in a writing state.")
            return
        }
        videoWriterInput?.markAsFinished()
    
        if let lastFrame = lastFrame, let firstFrameTime = firstFrameTime {
            let endTime = CMTimeAdd(CMSampleBufferGetPresentationTimeStamp(lastFrame), CMTimeMake(value: 1, timescale: 30))
            let adjustedEndTime = CMTimeSubtract(endTime, firstFrameTime)
            assetWriter.endSession(atSourceTime: adjustedEndTime)
        }
        assetWriter.finishWriting { [weak self] in
            self?.isRecording = false
            self?.stopCapturing()
            print("Recording finished.")
        }
    }
    
    private func prepareRecordingDirectoryAndFilename() throws -> URL {
        let fileManager = FileManager.default
        let documentsDirectory = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        let screenRecordsDirectory = documentsDirectory.appendingPathComponent("ScreenRecords")

        if !fileManager.fileExists(atPath: screenRecordsDirectory.path) {
            try fileManager.createDirectory(at: screenRecordsDirectory, withIntermediateDirectories: true)
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let dateString = dateFormatter.string(from: Date())
        let outputFileName = "capturedVideo_\(dateString).mov"
        return screenRecordsDirectory.appendingPathComponent(outputFileName)
    }
}
