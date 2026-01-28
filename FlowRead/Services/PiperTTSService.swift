// PiperTTSService.swift
// FlowRead - Piper ONNX-based Text-to-Speech Service

import Foundation
import OnnxRuntimeBindings
import AVFoundation

/// Piper TTS Service using ONNX Runtime
@MainActor
class PiperTTSService: ObservableObject {
    private var ortSession: ORTSession?
    private var ortEnv: ORTEnv?
    private var selectedVoice: PiperVoice = .amy_medium
    private var config: PiperConfig?

    /// Initialize the service
    init() {
        logDebug("PiperTTSService: Initializing (models will load on first use)...")
        logInfo("PiperTTS service initialized successfully")
    }

    /// Load the ONNX model for the selected voice
    func loadModel() throws {
        logInfo("PiperTTS: Loading model for \(selectedVoice.displayName)...")

        let modelPath = ModelDownloadManager.piperModelPath(for: selectedVoice)
        let configPath = ModelDownloadManager.piperConfigPath(for: selectedVoice)

        // Check if model files exist
        guard FileManager.default.fileExists(atPath: modelPath.path) else {
            throw PiperTTSError.modelNotDownloaded
        }

        guard FileManager.default.fileExists(atPath: configPath.path) else {
            throw PiperTTSError.configNotFound
        }

        do {
            // Load config
            let configData = try Data(contentsOf: configPath)
            config = try JSONDecoder().decode(PiperConfig.self, from: configData)

            // Initialize ONNX Runtime environment
            ortEnv = try ORTEnv(loggingLevel: .warning)

            // Create session options
            let sessionOptions = try ORTSessionOptions()
            try sessionOptions.setLogSeverityLevel(.warning)

            // Use CPU-only execution for stability
            logInfo("PiperTTS: Using CPU execution provider for stability")

            // Load the ONNX model
            ortSession = try ORTSession(
                env: ortEnv!,
                modelPath: modelPath.path,
                sessionOptions: sessionOptions
            )

            logInfo("PiperTTS: ✓✓✓ Model loaded successfully")
        } catch {
            logError("PiperTTS: ✗ Failed to load model - \(error.localizedDescription)")
            throw PiperTTSError.modelLoadFailed(error.localizedDescription)
        }
    }

    /// Set the voice for TTS
    func setVoice(_ voice: PiperVoice) {
        self.selectedVoice = voice
        // Reload model when voice changes
        ortSession = nil
        config = nil
        logInfo("PiperTTS: Voice set to: \(voice.displayName)")
    }

    /// Get current voice
    func getVoice() -> PiperVoice {
        return selectedVoice
    }

    /// Check if model is ready
    func isModelReady() -> Bool {
        return ortSession != nil && config != nil
    }

    /// Synthesize text to audio data
    func synthesize(text: String) async throws -> Data? {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            logDebug("PiperTTS: Empty text, skipping")
            return nil
        }

        // Load model if not already loaded
        if !isModelReady() {
            try loadModel()
        }

        guard let session = ortSession, let cfg = config else {
            throw PiperTTSError.modelNotInitialized
        }

        logInfo("PiperTTS: Synthesizing: '\(trimmedText.prefix(50))...' with \(selectedVoice.displayName)")

        do {
            // Convert text to phoneme IDs
            let phonemeIds = try textToPhonemeIds(text: trimmedText)
            logInfo("PiperTTS: Converted to \(phonemeIds.count) phoneme IDs")

            // Create input tensor
            let inputShape: [NSNumber] = [1, NSNumber(value: phonemeIds.count)]
            let inputData = Data(bytes: phonemeIds, count: phonemeIds.count * MemoryLayout<Int64>.size)
            let inputTensor = try ORTValue(
                tensorData: NSMutableData(data: inputData),
                elementType: .int64,
                shape: inputShape
            )

            // Get input/output names
            let inputNames = try session.inputNames()
            let outputNames = try session.outputNames()

            logDebug("PiperTTS: Model expects inputs: \(inputNames)")
            logDebug("PiperTTS: Model outputs: \(outputNames)")

            // Build input dictionary
            var inputs: [String: ORTValue] = [:]

            // Add main input (phoneme IDs)
            if let mainInputName = inputNames.first(where: { $0.contains("input") || $0 == "input" }) {
                inputs[mainInputName] = inputTensor
                logDebug("PiperTTS: Using '\(mainInputName)' for phoneme IDs")
            }

            // Add scales if required (noise_scale, length_scale, noise_w)
            if inputNames.contains(where: { $0.contains("scales") || $0 == "scales" }) {
                // Use config values or defaults
                let noiseScale = Float(cfg.inference?.noiseScale ?? 0.667)
                let lengthScale = Float(cfg.inference?.lengthScale ?? 1.0)
                let noiseW = Float(cfg.inference?.noiseW ?? 0.8)

                let scalesVector: [Float] = [noiseScale, lengthScale, noiseW]
                let scalesShape: [NSNumber] = [NSNumber(value: scalesVector.count)]
                let scalesData = Data(bytes: scalesVector, count: scalesVector.count * MemoryLayout<Float>.size)
                let scalesTensor = try ORTValue(
                    tensorData: NSMutableData(data: scalesData),
                    elementType: .float,
                    shape: scalesShape
                )

                if let scalesInputName = inputNames.first(where: { $0.contains("scales") || $0 == "scales" }) {
                    inputs[scalesInputName] = scalesTensor
                    logDebug("PiperTTS: Using '\(scalesInputName)' for scales [\(noiseScale), \(lengthScale), \(noiseW)]")
                }
            }

            // Add input_lengths if required
            if inputNames.contains(where: { $0.contains("input_lengths") || $0 == "input_lengths" }) {
                let lengths: [Int64] = [Int64(phonemeIds.count)]
                let lengthsShape: [NSNumber] = [1]
                let lengthsData = Data(bytes: lengths, count: lengths.count * MemoryLayout<Int64>.size)
                let lengthsTensor = try ORTValue(
                    tensorData: NSMutableData(data: lengthsData),
                    elementType: .int64,
                    shape: lengthsShape
                )

                if let lengthsInputName = inputNames.first(where: { $0.contains("input_lengths") || $0 == "input_lengths" }) {
                    inputs[lengthsInputName] = lengthsTensor
                    logDebug("PiperTTS: Using '\(lengthsInputName)' for input lengths")
                }
            }

            guard !inputs.isEmpty else {
                throw PiperTTSError.synthesizeFailed("Could not match model input names")
            }

            logInfo("PiperTTS: Running inference with \(inputs.count) inputs...")

            // Run inference
            let outputs = try session.run(
                withInputs: inputs,
                outputNames: Set(outputNames),
                runOptions: nil
            )

            guard let outputName = outputNames.first,
                  let outputTensor = outputs[outputName] else {
                throw PiperTTSError.synthesizeFailed("Failed to get model output")
            }

            // Get audio data from output tensor (FLOAT32 format)
            let tensorShape = try outputTensor.tensorTypeAndShapeInfo().shape
            logDebug("PiperTTS: Output tensor shape: \(tensorShape)")
            let tensorData = try outputTensor.tensorData() as Data
            logInfo("PiperTTS: Model output size: \(tensorData.count) bytes (\(tensorData.count / 4) float32 samples)")

            // Convert float32 audio samples to int16 PCM
            logDebug("PiperTTS: Converting float32 samples to int16 PCM...")
            let pcmData = convertFloat32ToInt16PCM(tensorData)
            logInfo("PiperTTS: ✓ Converted to PCM: \(pcmData.count) bytes")

            // Convert PCM to WAV format
            let sampleRate = cfg.audio?.sampleRate ?? 22050
            let wavData = try convertToWAV(rawAudio: pcmData, sampleRate: sampleRate)
            logInfo("PiperTTS: WAV audio size: \(wavData.count) bytes")

            return wavData
        } catch {
            logInfo("PiperTTS: ✗ Synthesis failed - \(error)")
            throw PiperTTSError.synthesizeFailed(error.localizedDescription)
        }
    }

    /// Convert text to phoneme IDs using espeak-ng phonemization
    private func textToPhonemeIds(text: String) throws -> [Int64] {
        // Try multiple locations for the phonemizer script
        var searchPaths: [String] = []

        // 1. App bundle Resources folder (production)
        if let resourcePath = Bundle.main.resourcePath {
            searchPaths.append(URL(fileURLWithPath: resourcePath).appendingPathComponent("piper_phonemizer.py").path)
        }

        // 2. Development location (same directory as this file)
        let devScriptPath = #file.replacingOccurrences(of: "PiperTTSService.swift", with: "piper_phonemizer.py")
        searchPaths.append(devScriptPath)

        // 3. Try current working directory
        searchPaths.append("FlowRead/Services/piper_phonemizer.py")

        // Find the first path that exists
        guard let finalScriptPath = searchPaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            logError("PiperTTS: Phonemizer script not found. Searched:")
            for path in searchPaths {
                logError("  - \(path)")
            }
            throw PiperTTSError.phonemizerNotFound
        }

        logDebug("PiperTTS: Using phonemizer at: \(finalScriptPath)")

        // Determine espeak voice from selected voice
        let espeakVoice = "en-us" // Both amy and ryan use en-us

        // Run the phonemizer script
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = [finalScriptPath, text, espeakVoice]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()

            // Check exit status
            guard process.terminationStatus == 0 else {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                logError("PiperTTS: Phonemizer failed - \(errorMessage)")
                throw PiperTTSError.phonemizationFailed(errorMessage)
            }

            // Parse JSON output
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()

            guard let jsonResult = try? JSONSerialization.jsonObject(with: outputData) as? [String: Any],
                  let success = jsonResult["success"] as? Bool,
                  success,
                  let phonemeIds = jsonResult["phoneme_ids"] as? [Int] else {
                throw PiperTTSError.phonemizationFailed("Invalid JSON response from phonemizer")
            }

            logDebug("PiperTTS: Phonemizer returned \(phonemeIds.count) phoneme IDs")

            return phonemeIds.map { Int64($0) }

        } catch let error as PiperTTSError {
            throw error
        } catch {
            logError("PiperTTS: Failed to run phonemizer - \(error.localizedDescription)")
            throw PiperTTSError.phonemizationFailed(error.localizedDescription)
        }
    }

    /// Convert float32 audio samples to int16 PCM format with dynamic normalization
    /// Uses Piper's normalization approach: scale to use full int16 dynamic range
    private func convertFloat32ToInt16PCM(_ float32Data: Data) -> Data {
        // Read float32 samples from tensor output
        let floatCount = float32Data.count / MemoryLayout<Float>.size
        var floatSamples = [Float](repeating: 0, count: floatCount)
        float32Data.withUnsafeBytes { rawBuffer in
            if let baseAddress = rawBuffer.baseAddress {
                floatSamples = Array(UnsafeBufferPointer(
                    start: baseAddress.assumingMemoryBound(to: Float.self),
                    count: floatCount
                ))
            }
        }

        // Find maximum absolute value for normalization
        let maxAbsValue = floatSamples.map { abs($0) }.max() ?? 0.01
        let normalizationFactor = 32767.0 / max(0.01, maxAbsValue)

        logDebug("PiperTTS: Audio max amplitude: \(maxAbsValue), normalization factor: \(normalizationFactor)")

        // Convert each float32 sample to int16 with dynamic normalization
        var int16Samples = [Int16](repeating: 0, count: floatCount)
        for i in 0..<floatCount {
            // Normalize and scale to int16 range
            let normalizedSample = floatSamples[i] * Float(normalizationFactor)
            // Clamp to valid int16 range
            let clampedSample = max(-32767.0, min(32767.0, normalizedSample))
            int16Samples[i] = Int16(clampedSample)
        }

        // Convert int16 array to Data
        return Data(bytes: int16Samples, count: int16Samples.count * MemoryLayout<Int16>.size)
    }

    /// Convert raw audio samples to WAV format
    private func convertToWAV(rawAudio: Data, sampleRate: Int) throws -> Data {
        let numChannels: Int16 = 1
        let bitsPerSample: Int16 = 16

        let dataSize = Int32(rawAudio.count)
        let fileSize = 36 + dataSize

        var wavData = Data()

        // RIFF header
        wavData.append("RIFF".data(using: .ascii)!)
        wavData.append(contentsOf: withUnsafeBytes(of: fileSize.littleEndian) { Array($0) })
        wavData.append("WAVE".data(using: .ascii)!)

        // fmt chunk
        wavData.append("fmt ".data(using: .ascii)!)
        wavData.append(contentsOf: withUnsafeBytes(of: Int32(16).littleEndian) { Array($0) })
        wavData.append(contentsOf: withUnsafeBytes(of: Int16(1).littleEndian) { Array($0) })
        wavData.append(contentsOf: withUnsafeBytes(of: numChannels.littleEndian) { Array($0) })
        wavData.append(contentsOf: withUnsafeBytes(of: Int32(sampleRate).littleEndian) { Array($0) })

        let byteRate = Int32(sampleRate) * Int32(numChannels) * Int32(bitsPerSample) / 8
        wavData.append(contentsOf: withUnsafeBytes(of: byteRate.littleEndian) { Array($0) })

        let blockAlign = numChannels * bitsPerSample / 8
        wavData.append(contentsOf: withUnsafeBytes(of: blockAlign.littleEndian) { Array($0) })
        wavData.append(contentsOf: withUnsafeBytes(of: bitsPerSample.littleEndian) { Array($0) })

        // data chunk
        wavData.append("data".data(using: .ascii)!)
        wavData.append(contentsOf: withUnsafeBytes(of: dataSize.littleEndian) { Array($0) })
        wavData.append(rawAudio)

        return wavData
    }

    /// Clean up resources
    deinit {
        ortSession = nil
        ortEnv = nil
        config = nil
        logInfo("PiperTTS: Service deinitialized")
    }
}

// MARK: - Piper Config Model

struct PiperConfig: Codable {
    let audio: AudioConfig?
    let espeak: EspeakConfig?
    let inference: InferenceConfig?

    struct AudioConfig: Codable {
        let sampleRate: Int

        enum CodingKeys: String, CodingKey {
            case sampleRate = "sample_rate"
        }
    }

    struct EspeakConfig: Codable {
        let voice: String?
    }

    struct InferenceConfig: Codable {
        let noiseScale: Double?
        let lengthScale: Double?
        let noiseW: Double?

        enum CodingKeys: String, CodingKey {
            case noiseScale = "noise_scale"
            case lengthScale = "length_scale"
            case noiseW = "noise_w"
        }
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
            return "Piper phonemizer script not found"
        case .phonemizationFailed(let message):
            return "Phonemization failed: \(message)"
        }
    }
}
