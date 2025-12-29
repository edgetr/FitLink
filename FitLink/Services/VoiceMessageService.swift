import Foundation
import AVFoundation
import FirebaseStorage

enum VoiceMessageError: LocalizedError, Sendable {
    case recordingNotAvailable
    case recordingFailed
    case playbackFailed
    case uploadFailed
    case downloadFailed
    case compressionFailed
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .recordingNotAvailable:
            return "Audio recording is not available"
        case .recordingFailed:
            return "Failed to record audio"
        case .playbackFailed:
            return "Failed to play audio"
        case .uploadFailed:
            return "Failed to upload voice message"
        case .downloadFailed:
            return "Failed to download voice message"
        case .compressionFailed:
            return "Failed to compress audio"
        case .permissionDenied:
            return "Microphone access denied"
        }
    }
}

actor VoiceMessageService {
    
    static let shared = VoiceMessageService()
    
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var currentRecordingURL: URL?
    private var recordingStartTime: Date?
    
    private let storage = Storage.storage()
    private let voiceMessagesPath = "voice_messages"
    
    private init() {}
    
    func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
    func startRecording() async throws -> URL {
        let hasPermission = await requestMicrophonePermission()
        guard hasPermission else {
            throw VoiceMessageError.permissionDenied
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try audioSession.setActive(true)
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = documentsPath.appendingPathComponent("\(UUID().uuidString).m4a")
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        let recorder = try AVAudioRecorder(url: audioFilename, settings: settings)
        recorder.record()
        
        self.audioRecorder = recorder
        self.currentRecordingURL = audioFilename
        self.recordingStartTime = Date()
        
        return audioFilename
    }
    
    func stopRecording() async throws -> (url: URL, duration: TimeInterval) {
        guard let recorder = audioRecorder,
              let url = currentRecordingURL,
              let startTime = recordingStartTime else {
            throw VoiceMessageError.recordingFailed
        }
        
        let duration = Date().timeIntervalSince(startTime)
        recorder.stop()
        
        self.audioRecorder = nil
        self.recordingStartTime = nil
        
        return (url, duration)
    }
    
    func cancelRecording() {
        audioRecorder?.stop()
        audioRecorder?.deleteRecording()
        audioRecorder = nil
        currentRecordingURL = nil
        recordingStartTime = nil
    }
    
    var isRecording: Bool {
        audioRecorder?.isRecording ?? false
    }
    
    var currentRecordingDuration: TimeInterval {
        guard let startTime = recordingStartTime else { return 0 }
        return Date().timeIntervalSince(startTime)
    }
    
    func uploadVoiceMessage(localURL: URL, chatId: String, messageId: String) async throws -> String {
        let data = try Data(contentsOf: localURL)
        
        let storageRef = storage.reference()
            .child(voiceMessagesPath)
            .child(chatId)
            .child("\(messageId).m4a")
        
        let metadata = StorageMetadata()
        metadata.contentType = "audio/m4a"
        
        _ = try await storageRef.putDataAsync(data, metadata: metadata)
        let downloadURL = try await storageRef.downloadURL()
        
        try? FileManager.default.removeItem(at: localURL)
        
        return downloadURL.absoluteString
    }
    
    func downloadVoiceMessage(url: String) async throws -> URL {
        guard let downloadURL = URL(string: url) else {
            throw VoiceMessageError.downloadFailed
        }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let localURL = documentsPath.appendingPathComponent("voice_\(UUID().uuidString).m4a")
        
        let (data, _) = try await URLSession.shared.data(from: downloadURL)
        try data.write(to: localURL)
        
        return localURL
    }
    
    func playVoiceMessage(url: URL) async throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playback, mode: .default)
        try audioSession.setActive(true)
        
        let player = try AVAudioPlayer(contentsOf: url)
        player.prepareToPlay()
        player.play()
        
        self.audioPlayer = player
    }
    
    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
    }
    
    var isPlaying: Bool {
        audioPlayer?.isPlaying ?? false
    }
    
    var playbackProgress: TimeInterval {
        audioPlayer?.currentTime ?? 0
    }
    
    var playbackDuration: TimeInterval {
        audioPlayer?.duration ?? 0
    }
    
    func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
