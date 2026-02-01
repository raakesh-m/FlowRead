// PersistedState.swift
// FlowRead - State persistence model

import Foundation

/// Structure for persisting app state between sessions
struct PersistedState: Codable {
    // PDF State
    var lastPDFPath: String?
    var lastPDFBookmark: Data?
    var lastReadingPosition: Int?
    
    // Playback Settings
    var playbackSpeed: Double
    var autoScrollEnabled: Bool
    
    // Voice Settings (order matches AppState.saveState() call)
    var selectedVoice: String?  // Groq voice
    
    // Display Settings
    var fontSize: Double?
    var lineSpacing: Double?
    
    // TTS Settings
    var isTTSEnabled: Bool
    var selectedTTSEngine: String?
    var selectedNativeVoice: String?
    var selectedPiperVoice: String?
    var selectedOpenAIVoice: String?  // OpenAI voice
    
    // Default state
    static var `default`: PersistedState {
        PersistedState(
            lastPDFPath: nil,
            lastPDFBookmark: nil,
            lastReadingPosition: nil,
            playbackSpeed: 1.0,
            autoScrollEnabled: true,
            selectedVoice: nil,
            fontSize: 17.0,
            lineSpacing: 10.0,
            isTTSEnabled: true,
            selectedTTSEngine: TTSEngine.macOSNative.rawValue,
            selectedNativeVoice: NativeVoice.samantha.rawValue,
            selectedPiperVoice: PiperVoice.amy_medium.rawValue,
            selectedOpenAIVoice: OpenAIVoice.nova.rawValue
        )
    }
}

