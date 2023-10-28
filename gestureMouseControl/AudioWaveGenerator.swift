import AVFoundation

class AudioWaveGenerator {
    private var audioEngine = AVAudioEngine()
    private let sampleRate: Double = 44100.0
    private let amplitude: Float = 0.5
    private let minFrequency: Float = 80.0
    private let maxFrequency: Float = 140.0
    private var isStopping: Bool = false
    
    init() throws {
        try setupAudioEngine()
    }
    
    private func setupAudioEngine() throws {
        let audioFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)
        var phase: Float = 0.0
        let currentFrequency: Float = minFrequency
        
        let audioNode = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for frame in 0..<Int(frameCount) {
                let fadeOutFactor: Float = self.isStopping ? Float(Int(frameCount) - frame) / Float(frameCount) : 1.0
                let value = self.amplitude * sin(phase) * fadeOutFactor
                
                for buffer in ablPointer {
                    let buf: UnsafeMutableBufferPointer<Float> = UnsafeMutableBufferPointer(buffer)
                    buf[frame] = value
                }
                
                phase += 2 * .pi * currentFrequency / Float(self.sampleRate)
                if phase >= 2 * .pi {
                    phase -= 2 * .pi
                }
            }
            return noErr
        }
        
        audioEngine.attach(audioNode)
        audioEngine.connect(audioNode, to: audioEngine.outputNode, format: audioFormat)
        
        do {
            try audioEngine.start()
        } catch {
            throw AudioEngineError.startupFailure(error.localizedDescription)
        }
    }
    
    public func updateFrequency(value: Float) throws ->  Float {
        guard 0...0.3 ~= value else { throw AudioEngineError.invalidParameter }
        return minFrequency + ((maxFrequency - minFrequency) * value / 0.3)
    }
    
    public func stopEngine() {
        isStopping = true
        audioEngine.stop()
    }
    
    enum AudioEngineError: Error {
        case startupFailure(String)
        case invalidParameter
    }
}
