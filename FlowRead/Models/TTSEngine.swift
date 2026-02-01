// TTSEngine.swift
// FlowRead - TTS Engine definitions and management

import Foundation

/// Available TTS engines in FlowRead
enum TTSEngine: String, CaseIterable, Identifiable, Codable {
    case macOSNative = "macos_native"
    case groqAPI = "groq_api"
    case openAI = "openai"
    case piper = "piper"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .macOSNative:
            return "macOS Native"
        case .groqAPI:
            return "Groq API"
        case .openAI:
            return "OpenAI TTS"
        case .piper:
            return "Piper TTS"
        }
    }
    
    var description: String {
        switch self {
        case .macOSNative:
            return "Built-in macOS voices, works offline"
        case .groqAPI:
            return "Cloud-based neural voices, requires API key"
        case .openAI:
            return "Premium cloud TTS, requires API key ($15/1M chars)"
        case .piper:
            return "Lightweight local AI model, fast"
        }
    }
    
    var icon: String {
        switch self {
        case .macOSNative:
            return "apple.logo"
        case .groqAPI:
            return "cloud.fill"
        case .openAI:
            return "OpenAILogo"  // Custom asset, not SF Symbol
        case .piper:
            return "speaker.wave.3.fill"
        }
    }
    
    var requiresDownload: Bool {
        switch self {
        case .macOSNative, .groqAPI, .openAI:
            return false
        case .piper:
            return true
        }
    }
    
    var requiresAPIKey: Bool {
        return self == .groqAPI || self == .openAI
    }
    
    /// Estimated download size in bytes
    var downloadSize: Int64 {
        switch self {
        case .macOSNative, .groqAPI, .openAI:
            return 0
        case .piper:
            return 126_000_000  // ~126 MB (Amy + Ryan Medium)
        }
    }
    
    var downloadSizeFormatted: String {
        switch self {
        case .macOSNative, .groqAPI, .openAI:
            return "N/A"
        case .piper:
            return "~126 MB"
        }
    }
    
    var qualityRating: Int {
        switch self {
        case .macOSNative:
            return 3  // Good
        case .groqAPI:
            return 5  // Excellent
        case .openAI:
            return 5  // Excellent
        case .piper:
            return 4  // Very Good
        }
    }
    
    var qualityLabel: String {
        switch qualityRating {
        case 5: return "Excellent"
        case 4: return "Very Good"
        case 3: return "Good"
        default: return "Standard"
        }
    }
}

// MARK: - Piper Voice Options

enum PiperVoice: String, CaseIterable, Identifiable {
    case amy_medium = "en_US-amy-medium"
    case ryan_medium = "en_US-ryan-medium"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .amy_medium: return "Amy"
        case .ryan_medium: return "Ryan"
        }
    }
    
    var description: String {
        switch self {
        case .amy_medium: return "Female - Clear, professional"
        case .ryan_medium: return "Male - Warm, friendly"
        }
    }
    
    var gender: String {
        self == .amy_medium ? "Female" : "Male"
    }
    
    /// Direct download URL for the model
    var modelURL: URL {
        switch self {
        case .amy_medium:
            return URL(string: "https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/amy/medium/en_US-amy-medium.onnx")!
        case .ryan_medium:
            return URL(string: "https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/ryan/medium/en_US-ryan-medium.onnx")!
        }
    }
    
    /// Direct download URL for the config
    var configURL: URL {
        switch self {
        case .amy_medium:
            return URL(string: "https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/amy/medium/en_US-amy-medium.onnx.json")!
        case .ryan_medium:
            return URL(string: "https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/ryan/medium/en_US-ryan-medium.onnx.json")!
        }
    }
    
    var downloadSize: Int64 {
        63_000_000  // ~63 MB
    }
}
