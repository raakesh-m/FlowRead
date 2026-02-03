// PiperTTSService.swift
// FlowRead - Lightweight Piper TTS using Python backend
// No ONNX Runtime in Swift = App goes from 19 MB to ~3 MB!

import Foundation
import AVFoundation

/// Lightweight Piper TTS Service that uses Python for synthesis
/// All the heavy lifting (ONNX, neural network) happens in Python
/// This keeps the Swift app tiny while providing full offline TTS
@MainActor
class PiperTTSService: ObservableObject {
    
    private var selectedVoice: PiperVoice = .amy_medium
    private var pythonPath: String?
    private var synthesizeScriptPath: String?
    
    /// Initialize the service
    init() {
        logDebug("PiperTTSService: Initializing lightweight Python-based service...")
        findResources()
        logInfo("PiperTTS service initialized (Python backend)")
    }
    
    /// Find Python and synthesis script
    private func findResources() {
        // Find Python
        pythonPath = findPython()
        
        // Find synthesis script
        synthesizeScriptPath = findSynthesizeScript()
        
        if let python = pythonPath {
            logDebug("PiperTTS: Python at \(python)")
        }
        if let script = synthesizeScriptPath {
            logDebug("PiperTTS: Script at \(script)")
        }
    }
    
    /// Check if dependencies are ready
    func isModelReady() -> Bool {
        return pythonPath != nil && synthesizeScriptPath != nil
    }
    
    /// Load model (no-op for Python backend, model is loaded per-synthesis)
    func loadModel() throws {
        guard pythonPath != nil else {
            throw PiperTTSError.pythonNotFound
        }
        guard synthesizeScriptPath != nil else {
            throw PiperTTSError.phonemizerNotFound
        }
        
        // Check if model file exists
        let modelPath = ModelDownloadManager.piperModelPath(for: selectedVoice)
        guard FileManager.default.fileExists(atPath: modelPath.path) else {
            throw PiperTTSError.modelNotDownloaded
        }
        
        logInfo("PiperTTS: Model ready for \(selectedVoice.displayName)")
    }
    
    /// Set the voice for TTS
    func setVoice(_ voice: PiperVoice) {
        self.selectedVoice = voice
        logInfo("PiperTTS: Voice set to: \(voice.displayName)")
    }
    
    /// Get current voice
    func getVoice() -> PiperVoice {
        return selectedVoice
    }
    
    /// Synthesize text to audio data using Python
    func synthesize(text: String) async throws -> Data? {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            logDebug("PiperTTS: Empty text, skipping")
            return nil
        }
        
        guard let python = pythonPath else {
            throw PiperTTSError.pythonNotFound
        }
        
        guard let script = synthesizeScriptPath else {
            throw PiperTTSError.phonemizerNotFound
        }
        
        let modelPath = ModelDownloadManager.piperModelPath(for: selectedVoice)
        guard FileManager.default.fileExists(atPath: modelPath.path) else {
            throw PiperTTSError.modelNotDownloaded
        }
        
        // For long text, split into chunks
        let maxChunkLength = 300
        
        if trimmedText.count <= maxChunkLength {
            return try await synthesizeSingle(text: trimmedText, python: python, script: script, modelPath: modelPath.path)
        }
        
        // Split and synthesize
        logInfo("PiperTTS: Text too long (\(trimmedText.count) chars), splitting...")
        let chunks = splitTextIntoChunks(trimmedText, maxLength: maxChunkLength)
        
        var audioDataPieces: [Data] = []
        
        for (index, chunk) in chunks.enumerated() {
            logInfo("PiperTTS: Synthesizing chunk \(index + 1)/\(chunks.count)")
            if let audioData = try await synthesizeSingle(text: chunk, python: python, script: script, modelPath: modelPath.path) {
                audioDataPieces.append(audioData)
            }
        }
        
        guard !audioDataPieces.isEmpty else {
            return nil
        }
        
        return combineWAVFiles(audioDataPieces)
    }
    
    /// Synthesize a single chunk using Python
    private func synthesizeSingle(text: String, python: String, script: String, modelPath: String) async throws -> Data? {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                // Create temp file for output
                let tempDir = FileManager.default.temporaryDirectory
                let outputPath = tempDir.appendingPathComponent("piper_output_\(UUID().uuidString).wav")
                
                let process = Process()
                process.executableURL = URL(fileURLWithPath: python)
                process.arguments = [script, text, modelPath, outputPath.path]
                
                // Set up environment
                var env = ProcessInfo.processInfo.environment
                env["PATH"] = "/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin:" + (env["PATH"] ?? "")
                // Add user site-packages to Python path
                if let home = env["HOME"] {
                    let userSitePackages = "\(home)/Library/Python/3.12/lib/python/site-packages:\(home)/Library/Python/3.11/lib/python/site-packages:\(home)/Library/Python/3.10/lib/python/site-packages"
                    env["PYTHONPATH"] = userSitePackages + ":" + (env["PYTHONPATH"] ?? "")
                }
                process.environment = env
                
                let outputPipe = Pipe()
                let errorPipe = Pipe()
                process.standardOutput = outputPipe
                process.standardError = errorPipe
                
                do {
                    try process.run()
                    process.waitUntilExit()
                    
                    if process.terminationStatus == 0 {
                        // Read the output file
                        if FileManager.default.fileExists(atPath: outputPath.path) {
                            let audioData = try Data(contentsOf: outputPath)
                            try? FileManager.default.removeItem(at: outputPath)
                            continuation.resume(returning: audioData)
                        } else {
                            // Try to parse JSON output for base64 audio
                            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                            if let json = try? JSONSerialization.jsonObject(with: outputData) as? [String: Any],
                               let success = json["success"] as? Bool, success,
                               let audioB64 = json["audio_base64"] as? String,
                               let audioData = Data(base64Encoded: audioB64) {
                                continuation.resume(returning: audioData)
                            } else {
                                continuation.resume(returning: nil)
                            }
                        }
                    } else {
                        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                        let errorStr = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                        
                        Task { @MainActor in
                            logError("PiperTTS: \(errorStr)")
                        }
                        
                        // Try to parse JSON error
                        if let json = try? JSONSerialization.jsonObject(with: errorData) as? [String: Any],
                           let error = json["error"] as? String {
                            continuation.resume(throwing: PiperTTSError.synthesizeFailed(error))
                        } else {
                            continuation.resume(throwing: PiperTTSError.synthesizeFailed(errorStr))
                        }
                    }
                } catch {
                    continuation.resume(throwing: PiperTTSError.synthesizeFailed(error.localizedDescription))
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func findPython() -> String? {
        let paths = [
            "/usr/bin/python3",
            "/usr/local/bin/python3",
            "/opt/homebrew/bin/python3",
            "/Library/Frameworks/Python.framework/Versions/Current/bin/python3",
            "/Library/Frameworks/Python.framework/Versions/3.12/bin/python3",
            "/Library/Frameworks/Python.framework/Versions/3.11/bin/python3"
        ]
        
        for path in paths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        
        // Try which
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["python3"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        
        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } catch {}
        
        return nil
    }
    
    private func findSynthesizeScript() -> String? {
        var paths: [String] = []
        
        // App bundle
        if let resourcePath = Bundle.main.resourcePath {
            paths.append(URL(fileURLWithPath: resourcePath).appendingPathComponent("piper_synthesize.py").path)
        }
        
        // Development location
        let devPath = #file.replacingOccurrences(of: "PiperTTSService.swift", with: "piper_synthesize.py")
        paths.append(devPath)
        
        // Current directory
        paths.append("FlowRead/Services/piper_synthesize.py")
        
        for path in paths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        
        return nil
    }
    
    /// Split text into chunks at natural break points
    private func splitTextIntoChunks(_ text: String, maxLength: Int) -> [String] {
        var chunks: [String] = []
        var currentChunk = ""
        
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
        
        for (index, sentence) in sentences.enumerated() {
            let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            
            let delimiter = index < sentences.count - 1 ? ". " : ""
            let sentenceWithDelimiter = trimmed + delimiter
            
            if currentChunk.isEmpty {
                currentChunk = sentenceWithDelimiter
            } else if (currentChunk + sentenceWithDelimiter).count <= maxLength {
                currentChunk += sentenceWithDelimiter
            } else {
                if !currentChunk.isEmpty {
                    chunks.append(currentChunk.trimmingCharacters(in: .whitespacesAndNewlines))
                }
                currentChunk = sentenceWithDelimiter
            }
            
            // Handle very long sentences
            if currentChunk.count > maxLength {
                let subChunks = splitLongSentence(currentChunk, maxLength: maxLength)
                chunks.append(contentsOf: subChunks.dropLast())
                currentChunk = subChunks.last ?? ""
            }
        }
        
        if !currentChunk.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            chunks.append(currentChunk.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        
        return chunks.filter { !$0.isEmpty }
    }
    
    private func splitLongSentence(_ sentence: String, maxLength: Int) -> [String] {
        var chunks: [String] = []
        var remaining = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        
        while !remaining.isEmpty {
            if remaining.count <= maxLength {
                chunks.append(remaining)
                break
            }
            
            let searchRange = String(remaining.prefix(maxLength))
            var bestBreak: String.Index? = nil
            
            // Try punctuation
            for breakPoint in [", ", "; ", ": ", " - "] {
                if let range = searchRange.range(of: breakPoint, options: .backwards) {
                    bestBreak = range.upperBound
                    break
                }
            }
            
            // Try conjunctions
            if bestBreak == nil {
                for conjunction in [" and ", " but ", " or "] {
                    if let range = searchRange.range(of: conjunction, options: [.backwards, .caseInsensitive]) {
                        bestBreak = range.lowerBound
                        break
                    }
                }
            }
            
            // Fall back to space
            if bestBreak == nil {
                bestBreak = searchRange.lastIndex(of: " ")
            }
            
            if let breakIndex = bestBreak {
                let offset = searchRange.distance(from: searchRange.startIndex, to: breakIndex)
                let endIndex = remaining.index(remaining.startIndex, offsetBy: offset)
                let chunk = String(remaining[..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !chunk.isEmpty {
                    chunks.append(chunk)
                }
                remaining = String(remaining[endIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                chunks.append(String(remaining.prefix(maxLength)))
                remaining = String(remaining.dropFirst(maxLength)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        return chunks.filter { !$0.isEmpty }
    }
    
    /// Combine multiple WAV files
    private func combineWAVFiles(_ wavFiles: [Data]) -> Data {
        guard !wavFiles.isEmpty else { return Data() }
        guard wavFiles.count > 1 else { return wavFiles[0] }
        
        // Extract PCM from each WAV (skip 44-byte header)
        var combinedPCM = Data()
        var sampleRate: UInt32 = 22050
        
        for wavData in wavFiles {
            guard wavData.count > 44 else { continue }
            
            // Try to read sample rate from first file
            if combinedPCM.isEmpty && wavData.count >= 28 {
                wavData.withUnsafeBytes { ptr in
                    if let baseAddress = ptr.baseAddress {
                        sampleRate = baseAddress.load(fromByteOffset: 24, as: UInt32.self)
                    }
                }
            }
            
            combinedPCM.append(wavData.dropFirst(44))
        }
        
        // Create new WAV
        return createWAV(pcmData: combinedPCM, sampleRate: Int(sampleRate))
    }
    
    private func createWAV(pcmData: Data, sampleRate: Int) -> Data {
        var wav = Data()
        
        let numChannels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let byteRate = UInt32(sampleRate) * UInt32(numChannels) * UInt32(bitsPerSample) / 8
        let blockAlign = numChannels * bitsPerSample / 8
        let dataSize = UInt32(pcmData.count)
        let fileSize = 36 + dataSize
        
        // RIFF header
        wav.append("RIFF".data(using: .ascii)!)
        wav.append(contentsOf: withUnsafeBytes(of: fileSize.littleEndian) { Array($0) })
        wav.append("WAVE".data(using: .ascii)!)
        
        // fmt chunk
        wav.append("fmt ".data(using: .ascii)!)
        wav.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) })
        wav.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) })
        wav.append(contentsOf: withUnsafeBytes(of: numChannels.littleEndian) { Array($0) })
        wav.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Array($0) })
        wav.append(contentsOf: withUnsafeBytes(of: byteRate.littleEndian) { Array($0) })
        wav.append(contentsOf: withUnsafeBytes(of: blockAlign.littleEndian) { Array($0) })
        wav.append(contentsOf: withUnsafeBytes(of: bitsPerSample.littleEndian) { Array($0) })
        
        // data chunk
        wav.append("data".data(using: .ascii)!)
        wav.append(contentsOf: withUnsafeBytes(of: dataSize.littleEndian) { Array($0) })
        wav.append(pcmData)
        
        return wav
    }
}

// MARK: - Errors

enum PiperTTSError: Error, LocalizedError {
    case modelNotDownloaded
    case configNotFound
    case modelLoadFailed(String)
    case modelNotInitialized
    case synthesizeFailed(String)
    case phonemizerNotFound
    case phonemizationFailed(String)
    case pythonNotFound
    
    var errorDescription: String? {
        switch self {
        case .modelNotDownloaded:
            return "Piper model not downloaded. Please download it from Settings."
        case .configNotFound:
            return "Piper config file not found"
        case .modelLoadFailed(let message):
            return "Failed to load Piper model: \(message)"
        case .modelNotInitialized:
            return "Piper model not initialized"
        case .synthesizeFailed(let message):
            return "Piper synthesis failed: \(message)"
        case .phonemizerNotFound:
            return "Piper synthesis script not found"
        case .phonemizationFailed(let message):
            return "Synthesis failed: \(message)"
        case .pythonNotFound:
            return "Python 3 not found"
        }
    }
}
