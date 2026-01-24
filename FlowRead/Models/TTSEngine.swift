// TTSEngine.swift
// FlowRead - TTS Engine definitions and management

import Foundation

/// Available TTS engines in FlowRead
enum TTSEngine: String, CaseIterable, Identifiable, Codable {
    case macOSNative = "macos_native"
    case groqAPI = "groq_api"
    case kokoro = "kokoro"
    case piper = "piper"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .macOSNative:
            return "macOS Native"
        case .groqAPI:
            return "Groq API"
        case .kokoro:
            return "Kokoro-82M"
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
        case .kokoro:
            return "High-quality local AI model"
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
        case .kokoro:
            return "waveform.circle.fill"
        case .piper:
            return "speaker.wave.3.fill"
        }
    }
    
    var requiresDownload: Bool {
        switch self {
        case .macOSNative, .groqAPI:
            return false
        case .kokoro, .piper:
            return true
        }
    }
    
    var requiresAPIKey: Bool {
        return self == .groqAPI
    }
    
    /// Estimated download size in bytes
    var downloadSize: Int64 {
        switch self {
        case .macOSNative, .groqAPI:
            return 0
        case .kokoro:
            return 97_000_000  // ~97 MB (quantized model + voices)
        case .piper:
            return 126_000_000  // ~126 MB (Amy + Ryan Medium)
        }
    }
    
    var downloadSizeFormatted: String {
        switch self {
        case .macOSNative, .groqAPI:
            return "N/A"
        case .kokoro:
            return "~97 MB"
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
        case .kokoro:
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

// MARK: - Kokoro Voice Options

enum KokoroVoice: String, CaseIterable, Identifiable {
    // American Female
    case af_bella = "af_bella"
    case af_nicole = "af_nicole"
    case af_sarah = "af_sarah"
    case af_sky = "af_sky"
    
    // American Male
    case am_adam = "am_adam"
    case am_michael = "am_michael"
    
    // British Female
    case bf_emma = "bf_emma"
    case bf_isabella = "bf_isabella"
    
    // British Male
    case bm_george = "bm_george"
    case bm_lewis = "bm_lewis"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .af_bella: return "Bella"
        case .af_nicole: return "Nicole"
        case .af_sarah: return "Sarah"
        case .af_sky: return "Sky"
        case .am_adam: return "Adam"
        case .am_michael: return "Michael"
        case .bf_emma: return "Emma"
        case .bf_isabella: return "Isabella"
        case .bm_george: return "George"
        case .bm_lewis: return "Lewis"
        }
    }
    
    var description: String {
        switch self {
        case .af_bella: return "American Female - Warm tones"
        case .af_nicole: return "American Female - Dynamic range"
        case .af_sarah: return "American Female - Clear articulation"
        case .af_sky: return "American Female - Youthful energy"
        case .am_adam: return "American Male - Natural inflection"
        case .am_michael: return "American Male - Deeper tones"
        case .bf_emma: return "British Female - Elegant"
        case .bf_isabella: return "British Female - Soft tones"
        case .bm_george: return "British Male - Classic"
        case .bm_lewis: return "British Male - Mature tone"
        }
    }
    
    var gender: String {
        rawValue.hasPrefix("af_") || rawValue.hasPrefix("bf_") ? "Female" : "Male"
    }
    
    var accent: String {
        rawValue.hasPrefix("a") ? "American" : "British"
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

// MARK: - Model Download URLs

struct KokoroModelURLs {
    static let modelURL = URL(string: "https://huggingface.co/onnx-community/Kokoro-82M-v1.0-ONNX/resolve/main/onnx/model_quantized.onnx")!
    
    // Voice files are individual - download based on selected voice
    static func voiceURL(for voice: KokoroVoice) -> URL {
        URL(string: "https://huggingface.co/onnx-community/Kokoro-82M-v1.0-ONNX/resolve/main/voices/\(voice.rawValue).bin")!
    }
    
    // Also need tokenizer
    static let tokenizerURL = URL(string: "https://huggingface.co/onnx-community/Kokoro-82M-v1.0-ONNX/resolve/main/tokenizer.json")!
    
    static var modelSize: Int64 { 93_000_000 }  // ~93 MB (quantized model)
    static var voiceSize: Int64 { 1_000_000 }   // ~1 MB per voice
    static var tokenizerSize: Int64 { 3_000_000 }  // ~3 MB
}
