// NativeTTSService.swift
// FlowRead - macOS Native Text-to-Speech using NSSpeechSynthesizer

import Foundation
import AppKit
import AVFoundation

/// Available macOS Native Voices
/// Using actual voice names for reliable matching
enum NativeVoice: String, CaseIterable, Identifiable, Codable {
    case samantha = "Samantha"
    case daniel = "Daniel"
    
    var id: String { rawValue }
    
    var displayName: String { rawValue }
    
    var description: String {
        switch self {
        case .samantha: return "American Female - Clear"
        case .daniel: return "British Male - Premium"
        }
    }
    
    var gender: String {
        switch self {
        case .samantha: return "Female"
        case .daniel: return "Male"
        }
    }
    
    var accent: String {
        switch self {
        case .samantha: return "American"
        case .daniel: return "British"
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
        
        // Try to find a matching voice by name
        if let voiceName = findVoiceByName(selectedVoice.rawValue) {
            synthesizer = NSSpeechSynthesizer(voice: voiceName)
            print("[NativeTTS] Using voice: \(voiceName.rawValue)")
        } else {
            // Default to system voice
            synthesizer = NSSpeechSynthesizer()
            print("[NativeTTS] Using system default voice")
        }
        
        synthesizer?.delegate = self
    }
    
    private func findVoiceByName(_ name: String) -> NSSpeechSynthesizer.VoiceName? {
        let availableVoices = NSSpeechSynthesizer.availableVoices
        
        // Search for voice by name in attributes
        for voiceName in availableVoices {
            let attrs = NSSpeechSynthesizer.attributes(forVoice: voiceName)
            if let voiceNameAttr = attrs[.name] as? String {
                if voiceNameAttr.lowercased() == name.lowercased() {
                    // Also verify it's an English voice
                    let lang = attrs[.localeIdentifier] as? String ?? ""
                    if lang.hasPrefix("en") {
                        return voiceName
                    }
                }
            }
        }
        
        // Fallback: search in the voice identifier
        for voiceName in availableVoices {
            if voiceName.rawValue.contains(name) {
                let attrs = NSSpeechSynthesizer.attributes(forVoice: voiceName)
                let lang = attrs[.localeIdentifier] as? String ?? ""
                if lang.hasPrefix("en") {
                    return voiceName
                }
            }
        }
        
        return nil
    }
    
    /// Set the voice for TTS
    func setVoice(_ voice: NativeVoice) {
        self.selectedVoice = voice
        
        if let voiceName = findVoiceByName(voice.rawValue) {
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
        
        print("[NativeTTS] Synthesizing: '\(trimmedText.prefix(50))...' with \(selectedVoice.displayName)")
        
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
    
    /// Get list of available system voices (for debugging)
    static func getAvailableVoices() -> [(name: String, identifier: String, locale: String)] {
        return NSSpeechSynthesizer.availableVoices.compactMap { voiceName in
            let attrs = NSSpeechSynthesizer.attributes(forVoice: voiceName)
            let name = attrs[.name] as? String ?? voiceName.rawValue
            let lang = attrs[.localeIdentifier] as? String ?? ""
            
            // Only include English voices
            guard lang.hasPrefix("en") else { return nil }
            return (name: name, identifier: voiceName.rawValue, locale: lang)
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
