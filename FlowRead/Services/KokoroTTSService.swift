// KokoroTTSService.swift
// FlowRead - Kokoro ONNX-based Text-to-Speech Service

import Foundation
import OnnxRuntimeBindings
import AVFoundation

/// Kokoro TTS Service using ONNX Runtime
@MainActor
class KokoroTTSService: ObservableObject {
    private var ortSession: ORTSession?
    private var ortEnv: ORTEnv?
    private var tokenizer: KokoroTokenizer?
    private var selectedVoice: KokoroVoice = .af_bella

    /// Initialize the service
    init() {
        logDebug("KokoroTTSService: Initializing (models will load on first use)...")
        logInfo("KokoroTTS service initialized successfully")
    }

    /// Load the ONNX model and tokenizer
    func loadModel() throws {
        logInfo("KokoroTTS: Loading model...")

        // Check if model files exist
        let modelPath = ModelDownloadManager.kokoroModelPath.path
        let tokenizerPath = ModelDownloadManager.kokoroTokenizerPath.path

        logDebug("KokoroTTS: Model path: \(modelPath)")
        logDebug("KokoroTTS: Tokenizer path: \(tokenizerPath)")

        guard FileManager.default.fileExists(atPath: modelPath) else {
            logError("KokoroTTS: ✗ Model file not found at \(modelPath)")
            throw KokoroTTSError.modelNotDownloaded
        }

        guard FileManager.default.fileExists(atPath: tokenizerPath) else {
            logError("KokoroTTS: ✗ Tokenizer file not found at \(tokenizerPath)")
            throw KokoroTTSError.tokenizerNotFound
        }

        logInfo("KokoroTTS: ✓ Model and tokenizer files found")

        do {
            // Initialize ONNX Runtime environment
            logDebug("KokoroTTS: Initializing ONNX Runtime environment...")
            ortEnv = try ORTEnv(loggingLevel: .warning)

            // Create session options
            logDebug("KokoroTTS: Creating session options...")
            let sessionOptions = try ORTSessionOptions()
            try sessionOptions.setLogSeverityLevel(.warning)

            // Use CPU-only execution (CoreML has tensor construction issues)
            logInfo("KokoroTTS: Using CPU execution provider for stability")

            // Load the ONNX model
            logInfo("KokoroTTS: Loading ONNX model session...")
            ortSession = try ORTSession(
                env: ortEnv!,
                modelPath: ModelDownloadManager.kokoroModelPath.path,
                sessionOptions: sessionOptions
            )
            logInfo("KokoroTTS: ✓ ONNX session created")

            // Load tokenizer
            logDebug("KokoroTTS: Loading tokenizer...")
            tokenizer = try KokoroTokenizer(tokenizerPath: ModelDownloadManager.kokoroTokenizerPath)
            logInfo("KokoroTTS: ✓ Tokenizer loaded")

            logInfo("KokoroTTS: ✓✓✓ Model and tokenizer loaded successfully")
        } catch {
            logError("KokoroTTS: ✗ Failed to load model - \(error.localizedDescription)")
            throw KokoroTTSError.modelLoadFailed(error.localizedDescription)
        }
    }

    /// Set the voice for TTS
    func setVoice(_ voice: KokoroVoice) {
        self.selectedVoice = voice
        print("[KokoroTTS] Voice set to: \(voice.displayName)")
    }

    /// Get current voice
    func getVoice() -> KokoroVoice {
        return selectedVoice
    }

    /// Check if model is ready
    func isModelReady() -> Bool {
        return ortSession != nil && tokenizer != nil
    }

    /// Synthesize text to audio data
    func synthesize(text: String) async throws -> Data? {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            logDebug("KokoroTTS: Empty text, skipping")
            return nil
        }

        logInfo("KokoroTTS: Starting synthesis for '\(trimmedText.prefix(50))...' with \(selectedVoice.displayName)")

        // Load model if not already loaded
        if !isModelReady() {
            logInfo("KokoroTTS: Model not ready, loading now...")
            try loadModel()
        } else {
            logDebug("KokoroTTS: Model already loaded")
        }

        guard let session = ortSession, let tok = tokenizer else {
            logError("KokoroTTS: ✗ Model not initialized after load attempt")
            throw KokoroTTSError.modelNotInitialized
        }

        do {
            // Tokenize input text
            logDebug("KokoroTTS: Tokenizing text...")
            let tokenIds = tok.encode(trimmedText)
            logInfo("KokoroTTS: ✓ Tokenized to \(tokenIds.count) tokens")

            // Create input tensor
            logDebug("KokoroTTS: Creating input tensor...")
            let inputShape: [NSNumber] = [1, NSNumber(value: tokenIds.count)]
            let inputData = Data(bytes: tokenIds, count: tokenIds.count * MemoryLayout<Int64>.size)
            let inputTensor = try ORTValue(
                tensorData: NSMutableData(data: inputData),
                elementType: .int64,
                shape: inputShape
            )
            logDebug("KokoroTTS: ✓ Input tensor created with shape [1, \(tokenIds.count)] as int64")

            // Get input/output names from the model
            let inputNames = try session.inputNames()
            let outputNames = try session.outputNames()

            logDebug("KokoroTTS: Model expects inputs: \(inputNames)")
            logDebug("KokoroTTS: Model outputs: \(outputNames)")

            // Kokoro model expects three inputs: input_ids, style, and speed
            // Create a dummy style vector (256-dimensional zeros for now)
            // TODO: Load actual style from voice file (kokoro-voice-*.bin)
            let styleVector = [Float](repeating: 0.0, count: 256)
            let styleShape: [NSNumber] = [1, 256]
            let styleData = Data(bytes: styleVector, count: styleVector.count * MemoryLayout<Float>.size)
            let styleTensor = try ORTValue(
                tensorData: NSMutableData(data: styleData),
                elementType: .float,
                shape: styleShape
            )
            logDebug("KokoroTTS: ✓ Style tensor created with shape [1, 256]")

            // Create speed tensor (1.0 = normal speed)
            let speed: Float = 1.0
            let speedShape: [NSNumber] = [1]
            let speedData = Data(bytes: [speed], count: MemoryLayout<Float>.size)
            let speedTensor = try ORTValue(
                tensorData: NSMutableData(data: speedData),
                elementType: .float,
                shape: speedShape
            )
            logDebug("KokoroTTS: ✓ Speed tensor created with shape [1] (speed=\(speed))")

            // Build input dictionary
            var inputs: [String: ORTValue] = [:]

            // Find the correct input names
            if let textInputName = inputNames.first(where: { $0.contains("input") || $0.contains("ids") }) {
                inputs[textInputName] = inputTensor
                logDebug("KokoroTTS: Using '\(textInputName)' for text tokens")
            }

            if let styleInputName = inputNames.first(where: { $0.contains("style") }) {
                inputs[styleInputName] = styleTensor
                logDebug("KokoroTTS: Using '\(styleInputName)' for style vector")
            }

            if let speedInputName = inputNames.first(where: { $0.contains("speed") }) {
                inputs[speedInputName] = speedTensor
                logDebug("KokoroTTS: Using '\(speedInputName)' for speed control")
            }

            guard !inputs.isEmpty else {
                logError("KokoroTTS: ✗ Could not match model inputs")
                throw KokoroTTSError.synthesizeFailed("Could not match model input names")
            }

            logInfo("KokoroTTS: Running ONNX inference with \(inputs.count) inputs...")

            // Run inference
            let outputs = try session.run(
                withInputs: inputs,
                outputNames: Set(outputNames),
                runOptions: nil
            )
            logInfo("KokoroTTS: ✓ ONNX inference completed")

            guard let outputName = outputNames.first,
                  let outputTensor = outputs[outputName] else {
                logError("KokoroTTS: ✗ Failed to get model output")
                throw KokoroTTSError.synthesizeFailed("Failed to get model output")
            }

            // Get audio data from output tensor (FLOAT32 format)
            logDebug("KokoroTTS: Extracting audio data from output tensor...")
            let tensorShape = try outputTensor.tensorTypeAndShapeInfo().shape
            logDebug("KokoroTTS: Output tensor shape: \(tensorShape)")
            let tensorData = try outputTensor.tensorData() as Data
            logInfo("KokoroTTS: ✓ Model output size: \(tensorData.count) bytes (\(tensorData.count / 4) float32 samples)")

            // Convert float32 audio samples to int16 PCM
            logDebug("KokoroTTS: Converting float32 samples to int16 PCM...")
            let pcmData = convertFloat32ToInt16PCM(tensorData)
            logInfo("KokoroTTS: ✓ Converted to PCM: \(pcmData.count) bytes")

            // Convert PCM audio to WAV format
            logDebug("KokoroTTS: Creating WAV file...")
            let wavData = try convertToWAV(rawAudio: pcmData)
            logInfo("KokoroTTS: ✓✓✓ WAV audio generated: \(wavData.count) bytes")

            return wavData
        } catch {
            logError("KokoroTTS: ✗✗✗ Synthesis failed - \(error.localizedDescription)")
            throw KokoroTTSError.synthesizeFailed(error.localizedDescription)
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

        logDebug("KokoroTTS: Audio max amplitude: \(maxAbsValue), normalization factor: \(normalizationFactor)")

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
    private func convertToWAV(rawAudio: Data) throws -> Data {
        // Kokoro typically outputs 24kHz 16-bit PCM audio
        let sampleRate: Int32 = 24000
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
        wavData.append(contentsOf: withUnsafeBytes(of: Int32(16).littleEndian) { Array($0) }) // chunk size
        wavData.append(contentsOf: withUnsafeBytes(of: Int16(1).littleEndian) { Array($0) }) // PCM format
        wavData.append(contentsOf: withUnsafeBytes(of: numChannels.littleEndian) { Array($0) })
        wavData.append(contentsOf: withUnsafeBytes(of: sampleRate.littleEndian) { Array($0) })

        let byteRate = sampleRate * Int32(numChannels) * Int32(bitsPerSample) / 8
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
        tokenizer = nil
        print("[KokoroTTS] Service deinitialized")
    }
}

// MARK: - Errors

enum KokoroTTSError: Error, LocalizedError {
    case modelNotDownloaded
    case tokenizerNotFound
    case modelLoadFailed(String)
    case modelNotInitialized
    case synthesizeFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelNotDownloaded:
            return "Kokoro model not downloaded. Please download it from Settings."
        case .tokenizerNotFound:
            return "Kokoro tokenizer not found"
        case .modelLoadFailed(let message):
            return "Failed to load Kokoro model: \(message)"
        case .modelNotInitialized:
            return "Kokoro model not initialized"
        case .synthesizeFailed(let message):
            return "Kokoro synthesis failed: \(message)"
        }
    }
}
