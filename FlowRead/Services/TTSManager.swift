// TTSManager.swift
// FlowRead - Unified TTS Manager that coordinates between different TTS engines

import Foundation
import Combine

/// Unified TTS Manager that handles multiple TTS engines
@MainActor
class TTSManager: ObservableObject {
    
    // MARK: - TTS Services
    private let nativeTTS: NativeTTSService
    private let groqTTS: GroqTTSService
    // Kokoro and Piper will be added in Phase 2
    
    // MARK: - Current Engine
    @Published private(set) var currentEngine: TTSEngine = .macOSNative
    @Published private(set) var lastError: String?
    
    // MARK: - Voice Settings
    private var nativeVoice: NativeVoice = .samantha
    private var groqVoice: GroqVoice = .hannah
    private var kokoroVoice: KokoroVoice = .af_bella
    private var piperVoice: PiperVoice = .amy_medium
    
    // MARK: - Initialization
    init(groqService: GroqTTSService) {
        self.nativeTTS = NativeTTSService()
        self.groqTTS = groqService
        print("[TTSManager] Initialized with macOS Native as default engine")
    }
    
    // MARK: - Engine Selection
    
    func setEngine(_ engine: TTSEngine) {
        self.currentEngine = engine
        self.lastError = nil
        print("[TTSManager] Engine switched to: \(engine.displayName)")
    }
    
    func getEngine() -> TTSEngine {
        return currentEngine
    }
    
    // MARK: - Voice Selection
    
    func setNativeVoice(_ voice: NativeVoice) {
        self.nativeVoice = voice
        nativeTTS.setVoice(voice)
    }
    
    func setGroqVoice(_ voice: GroqVoice) async {
        self.groqVoice = voice
        await groqTTS.setVoice(voice)
    }
    
    func setKokoroVoice(_ voice: KokoroVoice) {
        self.kokoroVoice = voice
        // Will be implemented in Phase 2
    }
    
    func setPiperVoice(_ voice: PiperVoice) {
        self.piperVoice = voice
        // Will be implemented in Phase 2
    }
    
    func getNativeVoice() -> NativeVoice { nativeVoice }
    func getGroqVoice() -> GroqVoice { groqVoice }
    func getKokoroVoice() -> KokoroVoice { kokoroVoice }
    func getPiperVoice() -> PiperVoice { piperVoice }
    
    // MARK: - Synthesize
    
    /// Synthesize text to audio using the currently selected engine
    func synthesize(text: String) async throws -> Data? {
        lastError = nil
        
        do {
            switch currentEngine {
            case .macOSNative:
                print("[TTSManager] Synthesizing with macOS Native...")
                return try await synthesizeWithNative(text: text)
            case .groqAPI:
                print("[TTSManager] Synthesizing with Groq API...")
                return try await synthesizeWithGroq(text: text)
            case .kokoro:
                print("[TTSManager] Synthesizing with Kokoro...")
                return try await synthesizeWithKokoro(text: text)
            case .piper:
                print("[TTSManager] Synthesizing with Piper...")
                return try await synthesizeWithPiper(text: text)
            }
        } catch {
            lastError = error.localizedDescription
            print("[TTSManager] Synthesis error: \(error)")
            throw error
        }
    }
    
    /// Check if the current engine is ready to use
    func isEngineReady() -> Bool {
        switch currentEngine {
        case .macOSNative:
            return true  // Always ready
        case .groqAPI:
            return true  // Keys are checked when synthesizing
        case .kokoro:
            // Check if model is downloaded
            return FileManager.default.fileExists(atPath: ModelDownloadManager.kokoroModelPath.path)
        case .piper:
            // Check if at least one voice is downloaded
            let amyExists = FileManager.default.fileExists(atPath: ModelDownloadManager.piperModelPath(for: .amy_medium).path)
            let ryanExists = FileManager.default.fileExists(atPath: ModelDownloadManager.piperModelPath(for: .ryan_medium).path)
            return amyExists || ryanExists
        }
    }
    
    /// Check if text is valid for TTS
    func isValidForTTS(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else { return false }
        guard trimmed.count >= 2 else { return false }
        
        // Check for meaningful content
        let hasLetters = trimmed.unicodeScalars.contains { CharacterSet.letters.contains($0) }
        if !hasLetters { return false }
        
        return true
    }
    
    // MARK: - Private Synthesis Methods
    
    private func synthesizeWithNative(text: String) async throws -> Data? {
        do {
            let audioData = try await nativeTTS.synthesize(text: text)
            if let data = audioData {
                print("[TTSManager] Native TTS returned \(data.count) bytes")
            }
            return audioData
        } catch {
            print("[TTSManager] Native TTS failed: \(error)")
            throw error
        }
    }
    
    private func synthesizeWithGroq(text: String) async throws -> Data? {
        return try await groqTTS.synthesize(text: text)
    }
    
    private func synthesizeWithKokoro(text: String) async throws -> Data? {
        // Phase 2: ONNX-based Kokoro implementation
        // For now, fall back to native TTS with a warning
        print("[TTSManager] Kokoro TTS not yet implemented, falling back to macOS Native")
        lastError = "Kokoro engine not yet implemented - using macOS Native"
        return try await synthesizeWithNative(text: text)
    }
    
    private func synthesizeWithPiper(text: String) async throws -> Data? {
        // Phase 2: ONNX-based Piper implementation
        // For now, fall back to native TTS with a warning
        print("[TTSManager] Piper TTS not yet implemented, falling back to macOS Native")
        lastError = "Piper engine not yet implemented - using macOS Native"
        return try await synthesizeWithNative(text: text)
    }
    
    // MARK: - Engine Information
    
    /// Get human-readable status for the current engine
    func getEngineStatus() -> String {
        switch currentEngine {
        case .macOSNative:
            return "Ready - Using \(nativeVoice.displayName)"
        case .groqAPI:
            return "Ready - Using \(groqVoice.displayName)"
        case .kokoro:
            let ready = FileManager.default.fileExists(atPath: ModelDownloadManager.kokoroModelPath.path)
            if ready {
                return "Ready - Using \(kokoroVoice.displayName)"
            } else {
                return "Model Download Required"
            }
        case .piper:
            let amyExists = FileManager.default.fileExists(atPath: ModelDownloadManager.piperModelPath(for: .amy_medium).path)
            let ryanExists = FileManager.default.fileExists(atPath: ModelDownloadManager.piperModelPath(for: .ryan_medium).path)
            if amyExists || ryanExists {
                return "Ready - Using \(piperVoice.displayName)"
            } else {
                return "Model Download Required"
            }
        }
    }
    
    // MARK: - Reload API Keys (for Groq)
    
    func reloadGroqKeys() async {
        await groqTTS.reloadKeys()
    }
}

// MARK: - GroqTTSService Extension for API Key Check

extension GroqTTSService {
    func hasAPIKeys() async -> Bool {
        // The service handles key management internally
        return true
    }
}
