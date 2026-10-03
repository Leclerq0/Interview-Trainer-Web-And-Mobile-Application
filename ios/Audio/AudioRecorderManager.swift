import AVFoundation
import Combine
import Foundation
import SwiftUI

public enum AudioRecorderError: LocalizedError {
    case permissionDenied
    case failedToStart
    case sessionActivationFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Mikrofon izni verilmedi. Lütfen Ayarlar > Interview Trainer bölümünden mikrofon erişimine izin verin."
        case .failedToStart:
            return "Ses kaydedici başlatılamadı. Lütfen mikrofon bağlantısını ve ayarlarını kontrol edin."
        case .sessionActivationFailed(let err):
            return "Ses oturumu başlatılamadı: \(err.localizedDescription)"
        }
    }
}

@MainActor
public final class AudioRecorderManager: NSObject, ObservableObject {
    public static let shared = AudioRecorderManager()

    @Published public private(set) var isRecording = false
    @Published public private(set) var audioLevel: Float = 0.0 // 0.0 - 1.0 arası normalize seviye
    @Published public private(set) var recordingDuration: TimeInterval = 0.0

    private var audioRecorder: AVAudioRecorder?
    private var recordingTimer: Timer?
    private var tempFileURL: URL?

    public override init() {
        super.init()
    }

    public func requestPermission() async -> Bool {
        let currentStatus = AVAudioSession.sharedInstance().recordPermission
        switch currentStatus {
        case .granted:
            return true
        case .denied:
            return false
        case .undetermined:
            if #available(iOS 17.0, *) {
                return await AVAudioApplication.requestRecordPermission()
            } else {
                return await withCheckedContinuation { continuation in
                    AVAudioSession.sharedInstance().requestRecordPermission { granted in
                        continuation.resume(returning: granted)
                    }
                }
            }
        @unknown default:
            return false
        }
    }

    public func startRecording() async throws {
        let granted = await requestPermission()
        guard granted else {
            throw AudioRecorderError.permissionDenied
        }

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            throw AudioRecorderError.sessionActivationFailed(error)
        }

        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "interview_answer_\(UUID().uuidString).m4a"
        let fileURL = tempDir.appendingPathComponent(fileName)
        self.tempFileURL = fileURL

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        let recorder: AVAudioRecorder
        do {
            recorder = try AVAudioRecorder(url: fileURL, settings: settings)
        } catch {
            throw AudioRecorderError.sessionActivationFailed(error)
        }

        recorder.isMeteringEnabled = true
        
        let prepared = recorder.prepareToRecord()
        guard prepared else {
            let fallbackSettings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 22050.0,
                AVNumberOfChannelsKey: 1
            ]
            if let fallbackRecorder = try? AVAudioRecorder(url: fileURL, settings: fallbackSettings),
               fallbackRecorder.prepareToRecord(), fallbackRecorder.record() {
                fallbackRecorder.isMeteringEnabled = true
                self.audioRecorder = fallbackRecorder
                self.isRecording = true
                self.recordingDuration = 0.0
                startTimer()
                return
            }
            throw AudioRecorderError.failedToStart
        }

        guard recorder.record() else {
            throw AudioRecorderError.failedToStart
        }

        self.audioRecorder = recorder
        self.isRecording = true
        self.recordingDuration = 0.0

        startTimer()
    }

    private func startTimer() {
        recordingTimer?.invalidate()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, let recorder = self.audioRecorder, recorder.isRecording else { return }
                recorder.updateMeters()
                let power = recorder.averagePower(forChannel: 0) // -160 dB ile 0 dB
                let minDb: Float = -60.0
                let clamped = max(minDb, min(0, power))
                let normalized = (clamped - minDb) / (-minDb)
                self.audioLevel = normalized
                self.recordingDuration = recorder.currentTime
            }
        }
    }

    public func stopRecording() -> Data? {
        recordingTimer?.invalidate()
        recordingTimer = nil
        audioLevel = 0.0

        guard let recorder = audioRecorder, recorder.isRecording else {
            isRecording = false
            return nil
        }

        recorder.stop()
        isRecording = false
        audioRecorder = nil

        guard let fileURL = tempFileURL, FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        defer {
            try? FileManager.default.removeItem(at: fileURL)
            tempFileURL = nil
        }

        return try? Data(contentsOf: fileURL)
    }

    public func cancelRecording() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        audioLevel = 0.0

        if let recorder = audioRecorder, recorder.isRecording {
            recorder.stop()
        }
        isRecording = false
        audioRecorder = nil

        if let fileURL = tempFileURL {
            try? FileManager.default.removeItem(at: fileURL)
            tempFileURL = nil
        }
    }
}
