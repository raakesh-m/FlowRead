// NativeTTSService.swift
// FlowRead - macOS Native Text-to-Speech using NSSpeechSynthesizer

import Foundation
import AppKit
import AVFoundation

/// Available macOS Native Voices (commonly available)
enum NativeVoice: String, CaseIterable, Identifiable, Codable {
    // US English - Enhanced/Premium voices
    case samantha = "com.apple.voice.enhanced.en-US.Samantha"
    case allison = "com.apple.voice.enhanced.en-US.Allison"
    case ava = "com.apple.voice.enhanced.en-US.Ava"
    case tom = "com.apple.voice.enhanced.en-US.Tom"
    case alex = "com.apple.voice.enhanced.en-US.Alex"
    
    // UK English
    case daniel = "com.apple.voice.enhanced.en-GB.Daniel"
    case kate = "com.apple.voice.enhanced.en-GB.Kate"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .samantha: return "Samantha"
        case .alex: return "Alex"
        case .allison: return "Allison"
        case .ava: return "Ava"
        case .tom: return "Tom"
        case .daniel: return "Daniel"
        case .kate: return "Kate"
        }
    }
    
    var description: String {
        switch self {
        case .samantha: return "American Female - Clear"
        case .alex: return "American Male - Classic"
        case .allison: return "American Female - Friendly"
        case .ava: return "American Female - Natural"
        case .tom: return "American Male - Standard"
        case .daniel: return "British Male - Premium"
        case .kate: return "British Female - Elegant"
        }
    }
    
    var gender: String {
        switch self {
        case .samantha, .allison, .ava, .kate:
            return "Female"
        case .alex, .tom, .daniel:
            return "Male"
        }
    }
    
    var accent: String {
        switch self {
        case .samantha, .alex, .allison, .ava, .tom:
            return "American"
        case .daniel, .kate:
            return "British"
        }
    }
    
    /// Get the NSSpeechSynthesizer voice name
    var speechVoiceName: String {
        // NSSpeechSynthesizer uses a different naming convention
        switch self {
        case .samantha: return "Samantha"
        case .alex: return "Alex"
        case .allison: return "Allison"
        case .ava: return "Ava"
        case .tom: return "Tom"
        case .daniel: return "Daniel"
        case .kate: return "Kate"
        }
    }
}

/// macOS Native TTS Service using NSSpeechSynthesizer
@MainActor
class NativeTTSService: NSObject, ObservableObject {
    private var synthesizer: NSSpeechSynthesizer?
    private var selectedVoice: NativeVoice = .samantha
    private var tempFileURL: URL?
    
    private var synthesisCompletion: ((Result<Data, Error>) -> Void)?
    
    override init() {
        super.init()
        setupSynthesizer()
    }
    
    private func setupSynthesizer() {
        // Find available voice
        let availableVoices = NSSpeechSynthesizer.availableVoices
        print("[NativeTTS] Available voices: \(availableVoices.count)")
        
        // Try to find a matching voice
        if let voice = findBestVoice(for: selectedVoice) {
            synthesizer = NSSpeechSynthesizer(voice: voice)
            print("[NativeTTS] Using voice: \(voice.rawValue)")
        } else if let defaultVoice = availableVoices.first {
            synthesizer = NSSpeechSynthesizer(voice: defaultVoice)
            print("[NativeTTS] Using default voice: \(defaultVoice.rawValue)")
        } else {
            synthesizer = NSSpeechSynthesizer()
            print("[NativeTTS] Using system default voice")
        }
        
        synthesizer?.delegate = self
    }
    
    private func findBestVoice(for voice: NativeVoice) -> NSSpeechSynthesizer.VoiceName? {
        let availableVoices = NSSpeechSynthesizer.availableVoices
        
        // First try exact match
        if let found = availableVoices.first(where: { $0.rawValue.contains(voice.speechVoiceName) }) {
            return found
        }
        
        // Try to find any English voice as fallback
        return availableVoices.first(where: { voiceName in
            let attrs = NSSpeechSynthesizer.attributes(forVoice: voiceName)
            let lang = attrs[.localeIdentifier] as? String ?? ""
            return lang.hasPrefix("en")
        })
    }
    
    /// Set the voice for TTS
    func setVoice(_ voice: NativeVoice) {
        self.selectedVoice = voice
        if let voiceName = findBestVoice(for: voice) {
            synthesizer?.setVoice(voiceName)
            print("[NativeTTS] Voice set to: \(voice.displayName)")
        } else {
            print("[NativeTTS] Voice \(voice.displayName) not found, keeping current")
        }
    }
    
    /// Get current voice
    func getVoice() -> NativeVoice {
        return selectedVoice
    }
    
    /// Synthesize text to audio data
    /// Returns AIFF audio data that can be played by AudioPlaybackManager
    func synthesize(text: String) async throws -> Data? {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { 
            print("[NativeTTS] Empty text, skipping")
            return nil 
        }
        
        guard let synth = synthesizer else {
            throw NativeTTSError.synthesizeFailed("Synthesizer not initialized")
        }
        
        // Create temp file for audio output
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("tts_output_\(UUID().uuidString).aiff")
        self.tempFileURL = tempFile
        
        print("[NativeTTS] Synthesizing: '\(trimmedText.prefix(50))...' to \(tempFile.lastPathComponent)")
        
        return try await withCheckedThrowingContinuation { continuation in
            self.synthesisCompletion = { result in
                switch result {
                case .success(let data):
                    continuation.resume(returning: data)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            
            // Start synthesis to file
            let success = synth.startSpeaking(trimmedText, to: tempFile)
            if !success {
                self.synthesisCompletion = nil
                continuation.resume(throwing: NativeTTSError.synthesizeFailed("Failed to start synthesis"))
            }
        }
    }
    
    /// Stop current speech
    func stop() {
        synthesizer?.stopSpeaking()
    }
    
    /// Check if currently speaking
    func isSpeaking() -> Bool {
        return synthesizer?.isSpeaking ?? false
    }
    
    /// Get list of available system voices
    static func getAvailableVoices() -> [(name: String, identifier: String)] {
        return NSSpeechSynthesizer.availableVoices.compactMap { voiceName in
            let attrs = NSSpeechSynthesizer.attributes(forVoice: voiceName)
            let name = attrs[.name] as? String ?? voiceName.rawValue
            let lang = attrs[.localeIdentifier] as? String ?? ""
            
            // Only include English voices
            guard lang.hasPrefix("en") else { return nil }
            return (name: name, identifier: voiceName.rawValue)
        }
    }
}

// MARK: - NSSpeechSynthesizerDelegate

extension NativeTTSService: NSSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ sender: NSSpeechSynthesizer, didFinishSpeaking finishedSpeaking: Bool) {
        Task { @MainActor in
            guard let tempFile = self.tempFileURL else {
                self.synthesisCompletion?(.failure(NativeTTSError.synthesizeFailed("No temp file")))
                self.synthesisCompletion = nil
                return
            }
            
            if finishedSpeaking {
                do {
                    // Read the audio file
                    let audioData = try Data(contentsOf: tempFile)
                    print("[NativeTTS] Synthesis complete, audio size: \(audioData.count) bytes")
                    
                    // Clean up temp file
                    try? FileManager.default.removeItem(at: tempFile)
                    self.tempFileURL = nil
                    
                    self.synthesisCompletion?(.success(audioData))
                } catch {
                    print("[NativeTTS] Failed to read audio file: \(error)")
                    self.synthesisCompletion?(.failure(NativeTTSError.synthesizeFailed("Failed to read audio: \(error.localizedDescription)")))
                }
            } else {
                print("[NativeTTS] Synthesis was interrupted")
                try? FileManager.default.removeItem(at: tempFile)
                self.tempFileURL = nil
                self.synthesisCompletion?(.failure(NativeTTSError.cancelled))
            }
            self.synthesisCompletion = nil
        }
    }
    
    nonisolated func speechSynthesizer(_ sender: NSSpeechSynthesizer, willSpeakWord characterRange: NSRange, of string: String) {
        // Progress callback - could be used for word highlighting
    }
}

// MARK: - Errors

enum NativeTTSError: Error, LocalizedError {
    case synthesizeFailed(String)
    case voiceNotAvailable
    case cancelled
    
    var errorDescription: String? {
        switch self {
        case .synthesizeFailed(let message):
            return "Speech synthesis failed: \(message)"
        case .voiceNotAvailable:
            return "Selected voice is not available on this system"
        case .cancelled:
            return "Speech was cancelled"
        }
    }
}
