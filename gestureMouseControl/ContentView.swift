import SwiftUI
import Combine

struct ContentView: View {
    @StateObject private var cameraService = CameraManager()
    @StateObject private var handTrackingViewModel = HandTrackingViewModel()
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        if let previewLayer = cameraService.previewLayer {
            CameraPreview(previewLayer: previewLayer)
            .onAppear {
                cameraService.handPosePublisher
                    .receive(on: DispatchQueue.main)
                    .sink(receiveCompletion: { completion in
                        switch completion { 
                        case .finished:
                            break
                        case .failure(let error):
                            print("Error: \(error)")
                        }
                    }, receiveValue: { [handTrackingViewModel] observation in
                        handTrackingViewModel.process(hand: observation)
                    })
                    .store(in: &cancellables)
                cameraService.startSession()
                Task {
                    do {
                        try await ScreenRecorder.shared.startRecording()
                    } catch {
                        print("Screen recording failed to start: \(error)")
                    }
                }
            }
            .onDisappear {
                cameraService.stopSession()
            }
        }
    }
}
