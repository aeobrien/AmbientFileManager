import Foundation
import AVFoundation
import SwiftData

@Observable
class AudioPlayer {
    private var engine = AVAudioEngine()
    private var playerNode = AVAudioPlayerNode()
    private var varispeed = AVAudioUnitVarispeed()
    private var audioFile: AVAudioFile?
    private var timer: Timer?
    private var seekOffset: TimeInterval = 0

    var isPlaying = false
    var isPaused = false
    var currentSampleName: String = ""
    var currentSampleId: PersistentIdentifier?
    var duration: TimeInterval = 0
    var currentTime: TimeInterval = 0
    var semitoneOffset: Int = 0
    var trimDb: Double = 0
    var errorMessage: String?

    var hasLoadedFile: Bool { audioFile != nil }

    var rate: Float {
        pow(2.0, Float(semitoneOffset) / 12.0)
    }

    var volume: Float {
        Float(pow(10.0, trimDb / 20.0))
    }

    init() {
        engine.attach(playerNode)
        engine.attach(varispeed)
        engine.connect(playerNode, to: varispeed, format: nil)
        engine.connect(varispeed, to: engine.mainMixerNode, format: nil)
    }

    /// Load a sample into the transport display without playing it.
    func load(url: URL, name: String, sampleId: PersistentIdentifier, pitch: Int, trim: Double) {
        stop()
        errorMessage = nil
        semitoneOffset = pitch
        trimDb = trim
        currentSampleId = sampleId
        currentSampleName = name

        guard FileManager.default.fileExists(atPath: url.path) else {
            errorMessage = "File not found: \(url.lastPathComponent)"
            return
        }
        do {
            let file = try AVAudioFile(forReading: url)
            audioFile = file
            duration = Double(file.length) / file.processingFormat.sampleRate
            currentTime = 0
        } catch {
            errorMessage = "Could not load: \(error.localizedDescription)"
        }
    }

    func play(url: URL, name: String, sampleId: PersistentIdentifier, pitch: Int, trim: Double) {
        playerNode.stop()
        if engine.isRunning { engine.stop() }
        stopTimer()
        isPlaying = false
        isPaused = false
        seekOffset = 0
        currentTime = 0
        errorMessage = nil

        // Load sample-specific settings
        semitoneOffset = pitch
        trimDb = trim
        currentSampleId = sampleId
        currentSampleName = name

        guard FileManager.default.fileExists(atPath: url.path) else {
            errorMessage = "File not found: \(url.lastPathComponent)"
            return
        }

        do {
            let file = try AVAudioFile(forReading: url)
            audioFile = file
            duration = Double(file.length) / file.processingFormat.sampleRate
            varispeed.rate = rate
            playerNode.volume = volume

            playerNode.scheduleFile(file, at: nil, completionHandler: nil)
            try engine.start()
            playerNode.play()
            isPlaying = true
            isPaused = false
            startTimer()
        } catch {
            errorMessage = "Could not play: \(error.localizedDescription)"
        }
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else if isPaused {
            resume()
        }
    }

    func pause() {
        guard isPlaying else { return }
        playerNode.pause()
        isPlaying = false
        isPaused = true
        stopTimer()
    }

    func resume() {
        guard isPaused, audioFile != nil else { return }
        do {
            if !engine.isRunning {
                try engine.start()
            }
            playerNode.play()
            isPlaying = true
            isPaused = false
            startTimer()
        } catch {
            errorMessage = "Could not resume: \(error.localizedDescription)"
        }
    }

    func stop() {
        playerNode.stop()
        if engine.isRunning { engine.stop() }
        isPlaying = false
        isPaused = false
        currentTime = 0
        seekOffset = 0
        stopTimer()
    }

    func seek(to time: TimeInterval) {
        guard let file = audioFile else { return }

        let sampleRate = file.processingFormat.sampleRate
        let clampedTime = max(0, min(time, duration))
        let startFrame = AVAudioFramePosition(clampedTime * sampleRate)
        guard startFrame < file.length else {
            stop()
            return
        }

        let remainingFrames = AVAudioFrameCount(file.length - startFrame)

        playerNode.stop()
        playerNode.scheduleSegment(file, startingFrame: startFrame, frameCount: remainingFrames, at: nil, completionHandler: nil)

        seekOffset = clampedTime
        currentTime = clampedTime

        do {
            if !engine.isRunning {
                try engine.start()
            }
            playerNode.play()
            isPlaying = true
            isPaused = false
            startTimer()
        } catch {
            errorMessage = "Could not seek: \(error.localizedDescription)"
        }
    }

    func shiftPitch(by semitones: Int) {
        semitoneOffset += semitones
        varispeed.rate = rate
    }

    func resetPitch() {
        semitoneOffset = 0
        varispeed.rate = 1.0
    }

    func setTrim(_ db: Double) {
        trimDb = db
        playerNode.volume = volume
    }

    // MARK: - Timer

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.updateCurrentTime()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func updateCurrentTime() {
        guard let file = audioFile else { return }

        if isPlaying && !playerNode.isPlaying {
            isPlaying = false
            isPaused = false
            currentTime = 0
            seekOffset = 0
            stopTimer()
            return
        }

        guard isPlaying,
              let nodeTime = playerNode.lastRenderTime,
              let playerTime = playerNode.playerTime(forNodeTime: nodeTime) else { return }

        let nodeSeconds = Double(playerTime.sampleTime) / playerTime.sampleRate
        let absoluteTime = seekOffset + nodeSeconds
        if absoluteTime >= 0 && absoluteTime <= duration {
            currentTime = absoluteTime
        }
    }

    // MARK: - Offline Rendering

    static func renderToFile(inputURL: URL, outputURL: URL, rate: Float, volume: Float) throws {
        let inputFile = try AVAudioFile(forReading: inputURL)
        let format = inputFile.processingFormat

        let offlineEngine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        let vari = AVAudioUnitVarispeed()

        offlineEngine.attach(player)
        offlineEngine.attach(vari)
        offlineEngine.connect(player, to: vari, format: format)
        offlineEngine.connect(vari, to: offlineEngine.mainMixerNode, format: format)

        vari.rate = rate
        player.volume = volume

        let maxFrames: AVAudioFrameCount = 4096
        try offlineEngine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: maxFrames)
        try offlineEngine.start()

        player.scheduleFile(inputFile, at: nil)
        player.play()

        let outputFile = try AVAudioFile(forWriting: outputURL, settings: format.settings)
        let buffer = AVAudioPCMBuffer(pcmFormat: offlineEngine.manualRenderingFormat, frameCapacity: maxFrames)!

        // Estimate output length: input duration / rate
        let estimatedFrames = Int64(Double(inputFile.length) / Double(rate))
        var rendered: Int64 = 0

        while rendered < estimatedFrames + Int64(maxFrames) {
            let status = try offlineEngine.renderOffline(maxFrames, to: buffer)
            switch status {
            case .success:
                try outputFile.write(from: buffer)
                rendered += Int64(buffer.frameLength)
            case .insufficientDataFromInputNode:
                rendered += Int64(maxFrames)
            case .cannotDoInCurrentContext:
                rendered += Int64(maxFrames)
            case .error:
                throw NSError(domain: "AudioPlayer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Offline render error"])
            @unknown default:
                break
            }
        }

        offlineEngine.stop()
    }
}
