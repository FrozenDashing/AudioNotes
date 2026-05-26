import Flutter
import UIKit
import AVFoundation
import Foundation

/**
 * ASR Plugin for iOS
 * Handles audio recording, VAD, and Vosk speech recognition
 */
public class AsrPlugin: NSObject, FlutterPlugin {
    private var channel: FlutterMethodChannel?
    private var audioEngine: AVAudioEngine?
    private var isRecording = false
    
    // VAD parameters
    private var shortPauseMs: Int64 = 600
    private var longPauseMs: Int64 = 1500
    private var energyThreshold: Float = 0.3
    
    // Audio format
    private let sampleRate: Double = 16000.0
    private let channels: AVAudioChannelCount = 1
    
    private var silenceStartTime: TimeInterval = -1
    private var currentSegmentText = ""
    private var segmentStartTime: TimeInterval = 0
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.audionotes/asr",
            binaryMessenger: registrar.messenger()
        )
        let instance = AsrPlugin()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "start":
            handleStart(arguments: call.arguments, result: result)
        case "stop":
            handleStop(result: result)
        case "cancel":
            handleCancel(result: result)
        case "reRecord":
            handleReRecord(arguments: call.arguments, result: result)
        case "setVADParams":
            handleSetVADParams(arguments: call.arguments, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func handleStart(arguments: Any?, result: @escaping FlutterResult) {
        guard checkPermission() else {
            result(FlutterError(
                code: "PERMISSION_DENIED",
                message: "Microphone permission not granted",
                details: nil
            ))
            return
        }
        
        do {
            // Extract VAD parameters if provided
            if let args = arguments as? [String: Any] {
                if let shortPause = args["short_pause_ms"] as? Int {
                    shortPauseMs = Int64(shortPause)
                }
                if let longPause = args["long_pause_ms"] as? Int {
                    longPauseMs = Int64(longPause)
                }
                if let threshold = args["energy_threshold"] as? Double {
                    energyThreshold = Float(threshold)
                }
            }
            
            try startRecording()
            result(true)
        } catch {
            print("Error starting recording: \(error)")
            result(FlutterError(
                code: "START_FAILED",
                message: error.localizedDescription,
                details: nil
            ))
        }
    }
    
    private func handleStop(result: @escaping FlutterResult) {
        stopRecording()
        result(true)
    }
    
    private func handleCancel(result: @escaping FlutterResult) {
        cancelRecording()
        result(true)
    }
    
    private func handleReRecord(arguments: Any?, result: @escaping FlutterResult) {
        guard let args = arguments as? [String: Any],
              let segmentId = args["segment_id"] as? String else {
            result(FlutterError(
                code: "INVALID_SEGMENT",
                message: "Segment ID is required",
                details: nil
            ))
            return
        }
        
        // TODO: Implement re-record logic
        result(true)
    }
    
    private func handleSetVADParams(arguments: Any?, result: @escaping FlutterResult) {
        if let args = arguments as? [String: Any] {
            if let shortPause = args["short_pause_ms"] as? Int {
                shortPauseMs = Int64(shortPause)
            }
            if let longPause = args["long_pause_ms"] as? Int {
                longPauseMs = Int64(longPause)
            }
            if let threshold = args["energy_threshold"] as? Double {
                energyThreshold = Float(threshold)
            }
        }
        result(true)
    }
    
    private func checkPermission() -> Bool {
        let status = AVAudioSession.sharedInstance().recordPermission
        return status == .granted
    }
    
    private func startRecording() throws {
        if isRecording {
            print("Already recording")
            return
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .default)
        try audioSession.setActive(true)
        
        audioEngine = AVAudioEngine()
        guard let engine = audioEngine else {
            throw NSError(domain: "AsrPlugin", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create audio engine"])
        }
        
        let inputNode = engine.inputNode
        let recordingFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: sampleRate,
            channels: channels,
            interleaved: true
        )
        
        guard let format = recordingFormat else {
            throw NSError(domain: "AsrPlugin", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create audio format"])
        }
        
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer, at: time)
        }
        
        try engine.start()
        isRecording = true
        segmentStartTime = Date().timeIntervalSince1970
        
        print("Recording started")
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, at time: AVAudioTime) {
        guard let channelData = buffer.int16ChannelData?[0] else { return }
        
        let frameLength = Int(buffer.frameLength)
        let channelDataArray = Array(UnsafeBufferPointer(start: channelData, count: frameLength))
        
        // Calculate energy for VAD
        let energy = calculateEnergy(channelDataArray)
        let isSpeech = energy > energyThreshold
        
        if isSpeech {
            silenceStartTime = -1
            // TODO: Send audio chunk to Vosk for recognition
            simulatePartialTranscript()
        } else {
            if silenceStartTime < 0 {
                silenceStartTime = Date().timeIntervalSince1970
            } else {
                let silenceDuration = (Date().timeIntervalSince1970 - silenceStartTime) * 1000
                
                if silenceDuration >= Double(longPauseMs) && !currentSegmentText.isEmpty {
                    // Finalize segment
                    finalizeSegment()
                    currentSegmentText = ""
                    segmentStartTime = Date().timeIntervalSince1970
                    silenceStartTime = -1
                }
            }
        }
    }
    
    private func calculateEnergy(_ samples: [Int16]) -> Float {
        var sum: Float = 0
        for sample in samples {
            sum += pow(Float(sample), 2)
        }
        return sqrt(sum / Float(samples.count)) / 32768.0
    }
    
    private func simulatePartialTranscript() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let event: [String: Any] = [
                "event": "partial_transcript",
                "text": "Listening...",
                "timestamp": Int(Date().timeIntervalSince1970 * 1000)
            ]
            self.channel?.invokeMethod("onEvent", arguments: event)
        }
    }
    
    private func finalizeSegment() {
        let segmentId = UUID().uuidString
        let endTime = Date().timeIntervalSince1970
        let audioPath = saveAudioSegment(segmentId: segmentId)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let event: [String: Any] = [
                "event": "final_segment",
                "segment_id": segmentId,
                "text": self.currentSegmentText,
                "start_ts": Int(self.segmentStartTime * 1000),
                "end_ts": Int(endTime * 1000),
                "audio_path": audioPath,
                "confidence": 0.85
            ]
            self.channel?.invokeMethod("onEvent", arguments: event)
        }
    }
    
    private func saveAudioSegment(segmentId: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateStr = dateFormatter.string(from: Date())
        
        let audioDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("audio/\(dateStr)")
        
        try? FileManager.default.createDirectory(at: audioDir, withIntermediateDirectories: true)
        
        let audioFileURL = audioDir.appendingPathComponent("\(segmentId).pcm")
        // TODO: Actually write audio data to file
        
        return audioFileURL.path
    }
    
    private func stopRecording() {
        if !isRecording { return }
        
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil
        isRecording = false
        
        print("Recording stopped")
    }
    
    private func cancelRecording() {
        stopRecording()
        // Delete any temporary audio files
        print("Recording cancelled")
    }
}
