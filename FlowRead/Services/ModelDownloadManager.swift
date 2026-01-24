// ModelDownloadManager.swift
// FlowRead - Manages downloading and storing TTS models

import Foundation
import Combine

/// Download status for a model
enum ModelDownloadStatus: Equatable {
    case notDownloaded
    case downloading(progress: Double, bytesDownloaded: Int64, totalBytes: Int64)
    case downloaded
    case deleting
    case failed(error: String)
    
    var isDownloading: Bool {
        if case .downloading = self { return true }
        return false
    }
    
    var isDownloaded: Bool {
        if case .downloaded = self { return true }
        return false
    }
    
    var isDeleting: Bool {
        if case .deleting = self { return true }
        return false
    }
}

/// Manages downloading TTS models from Hugging Face
@MainActor
class ModelDownloadManager: ObservableObject {
    
    // MARK: - Published State
    @Published var kokoroStatus: ModelDownloadStatus = .notDownloaded
    @Published var piperAmyStatus: ModelDownloadStatus = .notDownloaded
    @Published var piperRyanStatus: ModelDownloadStatus = .notDownloaded
    
    // MARK: - Private Properties
    private var downloadTasks: [String: URLSessionDownloadTask] = [:]
    private var progressObservers: [String: NSKeyValueObservation] = [:]
    
    private let fileManager = FileManager.default
    private let session: URLSession
    
    // MARK: - Paths (nonisolated for access from other actors)
    nonisolated static let modelsDirectory: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("FlowRead/Models", isDirectory: true)
    }()
    
    nonisolated static let kokoroModelPath: URL = {
        modelsDirectory.appendingPathComponent("kokoro-v1.0-quantized.onnx")
    }()
    
    nonisolated static let kokoroTokenizerPath: URL = {
        modelsDirectory.appendingPathComponent("kokoro-tokenizer.json")
    }()
    
    nonisolated static func kokoroVoicePath(for voice: KokoroVoice) -> URL {
        modelsDirectory.appendingPathComponent("kokoro-voice-\(voice.rawValue).bin")
    }
    
    nonisolated static func piperModelPath(for voice: PiperVoice) -> URL {
        modelsDirectory.appendingPathComponent("\(voice.rawValue).onnx")
    }
    
    nonisolated static func piperConfigPath(for voice: PiperVoice) -> URL {
        modelsDirectory.appendingPathComponent("\(voice.rawValue).onnx.json")
    }
    
    // MARK: - Initialization
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 600  // 10 minutes for large downloads
        self.session = URLSession(configuration: config)
        
        // Check existing downloads
        checkExistingModels()
    }
    
    // MARK: - Check Existing Models
    func checkExistingModels() {
        print("[ModelDownload] Checking existing models...")
        
        // Reset all states first (unless currently downloading or deleting)
        if !kokoroStatus.isDownloading && !kokoroStatus.isDeleting {
            kokoroStatus = .notDownloaded
        }
        if !piperAmyStatus.isDownloading && !piperAmyStatus.isDeleting {
            piperAmyStatus = .notDownloaded
        }
        if !piperRyanStatus.isDownloading && !piperRyanStatus.isDeleting {
            piperRyanStatus = .notDownloaded
        }
        
        // Check Kokoro - need model, tokenizer, and at least one voice
        let kokoroModelExists = fileManager.fileExists(atPath: Self.kokoroModelPath.path)
        let kokoroTokenizerExists = fileManager.fileExists(atPath: Self.kokoroTokenizerPath.path)
        let kokoroVoiceExists = fileManager.fileExists(atPath: Self.kokoroVoicePath(for: .af_bella).path)
        
        print("[ModelDownload] Kokoro: model=\(kokoroModelExists), tokenizer=\(kokoroTokenizerExists), voice=\(kokoroVoiceExists)")
        
        if kokoroModelExists && kokoroTokenizerExists && kokoroVoiceExists {
            kokoroStatus = .downloaded
        }
        
        // Check Piper Amy
        let amyExists = fileManager.fileExists(atPath: Self.piperModelPath(for: .amy_medium).path)
        print("[ModelDownload] Piper Amy: exists=\(amyExists)")
        if amyExists {
            piperAmyStatus = .downloaded
        }
        
        // Check Piper Ryan
        let ryanExists = fileManager.fileExists(atPath: Self.piperModelPath(for: .ryan_medium).path)
        print("[ModelDownload] Piper Ryan: exists=\(ryanExists)")
        if ryanExists {
            piperRyanStatus = .downloaded
        }
        
        print("[ModelDownload] Status check complete - Kokoro: \(kokoroStatus), Amy: \(piperAmyStatus), Ryan: \(piperRyanStatus)")
    }
    
    // MARK: - Create Directory
    private func ensureModelsDirectory() throws {
        if !fileManager.fileExists(atPath: Self.modelsDirectory.path) {
            try fileManager.createDirectory(at: Self.modelsDirectory, withIntermediateDirectories: true)
            print("[ModelDownload] Created models directory: \(Self.modelsDirectory.path)")
        }
    }
    
    // MARK: - Download Kokoro Model
    func downloadKokoroModel() async {
        guard !kokoroStatus.isDownloading && !kokoroStatus.isDownloaded else { return }
        
        do {
            try ensureModelsDirectory()
        } catch {
            kokoroStatus = .failed(error: "Failed to create directory: \(error.localizedDescription)")
            return
        }
        
        let totalSize = KokoroModelURLs.modelSize + KokoroModelURLs.tokenizerSize + KokoroModelURLs.voiceSize
        kokoroStatus = .downloading(progress: 0, bytesDownloaded: 0, totalBytes: totalSize)
        
        do {
            // Download model file (~93 MB - 90% of total)
            print("[ModelDownload] Starting Kokoro model download...")
            try await downloadFile(
                from: KokoroModelURLs.modelURL,
                to: Self.kokoroModelPath,
                taskId: "kokoro_model"
            ) { [weak self] progress, downloaded, total in
                Task { @MainActor in
                    let overallProgress = progress * 0.90
                    self?.kokoroStatus = .downloading(progress: overallProgress, bytesDownloaded: downloaded, totalBytes: totalSize)
                }
            }
            
            // Download tokenizer (~3 MB - 7% of total)
            print("[ModelDownload] Starting Kokoro tokenizer download...")
            try await downloadFile(
                from: KokoroModelURLs.tokenizerURL,
                to: Self.kokoroTokenizerPath,
                taskId: "kokoro_tokenizer"
            ) { [weak self] progress, downloaded, total in
                Task { @MainActor in
                    let overallProgress = 0.90 + (progress * 0.07)
                    let overallDownloaded = KokoroModelURLs.modelSize + downloaded
                    self?.kokoroStatus = .downloading(progress: overallProgress, bytesDownloaded: overallDownloaded, totalBytes: totalSize)
                }
            }
            
            // Download default voice (af_bella - ~1 MB - 3% of total)
            let defaultVoice = KokoroVoice.af_bella
            print("[ModelDownload] Starting Kokoro voice (\(defaultVoice.displayName)) download...")
            try await downloadFile(
                from: KokoroModelURLs.voiceURL(for: defaultVoice),
                to: Self.kokoroVoicePath(for: defaultVoice),
                taskId: "kokoro_voice"
            ) { [weak self] progress, downloaded, total in
                Task { @MainActor in
                    let overallProgress = 0.97 + (progress * 0.03)
                    let overallDownloaded = KokoroModelURLs.modelSize + KokoroModelURLs.tokenizerSize + downloaded
                    self?.kokoroStatus = .downloading(progress: overallProgress, bytesDownloaded: overallDownloaded, totalBytes: totalSize)
                }
            }
            
            kokoroStatus = .downloaded
            print("[ModelDownload] Kokoro model downloaded successfully!")
            
        } catch {
            kokoroStatus = .failed(error: error.localizedDescription)
            print("[ModelDownload] Kokoro download failed: \(error)")
        }
    }
    
    // MARK: - Download Piper Model
    func downloadPiperModel(voice: PiperVoice) async {
        let status = voice == .amy_medium ? piperAmyStatus : piperRyanStatus
        guard !status.isDownloading && !status.isDownloaded else { return }
        
        do {
            try ensureModelsDirectory()
        } catch {
            updatePiperStatus(voice: voice, status: .failed(error: "Failed to create directory: \(error.localizedDescription)"))
            return
        }
        
        updatePiperStatus(voice: voice, status: .downloading(progress: 0, bytesDownloaded: 0, totalBytes: voice.downloadSize))
        
        do {
            // Download model file
            print("[ModelDownload] Starting Piper \(voice.displayName) model download...")
            try await downloadFile(
                from: voice.modelURL,
                to: Self.piperModelPath(for: voice),
                taskId: "piper_\(voice.rawValue)_model"
            ) { [weak self] progress, downloaded, total in
                Task { @MainActor in
                    // Model is ~99% of download
                    let overallProgress = progress * 0.99
                    self?.updatePiperStatus(voice: voice, status: .downloading(progress: overallProgress, bytesDownloaded: downloaded, totalBytes: voice.downloadSize))
                }
            }
            
            // Download config file (very small)
            print("[ModelDownload] Starting Piper \(voice.displayName) config download...")
            try await downloadFile(
                from: voice.configURL,
                to: Self.piperConfigPath(for: voice),
                taskId: "piper_\(voice.rawValue)_config"
            ) { [weak self] progress, _, _ in
                Task { @MainActor in
                    let overallProgress = 0.99 + (progress * 0.01)
                    self?.updatePiperStatus(voice: voice, status: .downloading(progress: overallProgress, bytesDownloaded: voice.downloadSize, totalBytes: voice.downloadSize))
                }
            }
            
            updatePiperStatus(voice: voice, status: .downloaded)
            print("[ModelDownload] Piper \(voice.displayName) downloaded successfully!")
            
        } catch {
            updatePiperStatus(voice: voice, status: .failed(error: error.localizedDescription))
            print("[ModelDownload] Piper \(voice.displayName) download failed: \(error)")
        }
    }
    
    private func updatePiperStatus(voice: PiperVoice, status: ModelDownloadStatus) {
        switch voice {
        case .amy_medium:
            piperAmyStatus = status
        case .ryan_medium:
            piperRyanStatus = status
        }
    }
    
    // MARK: - Cancel Download
    func cancelDownload(taskId: String) {
        downloadTasks[taskId]?.cancel()
        downloadTasks.removeValue(forKey: taskId)
        progressObservers.removeValue(forKey: taskId)
    }
    
    func cancelKokoroDownload() {
        cancelDownload(taskId: "kokoro_model")
        cancelDownload(taskId: "kokoro_tokenizer")
        cancelDownload(taskId: "kokoro_voice")
        kokoroStatus = .notDownloaded
    }
    
    func cancelPiperDownload(voice: PiperVoice) {
        cancelDownload(taskId: "piper_\(voice.rawValue)_model")
        cancelDownload(taskId: "piper_\(voice.rawValue)_config")
        updatePiperStatus(voice: voice, status: .notDownloaded)
    }
    
    // MARK: - Delete Model
    func deleteKokoroModel() {
        guard !kokoroStatus.isDeleting else { return }
        
        kokoroStatus = .deleting
        print("[ModelDownload] Deleting Kokoro model...")
        
        Task {
            // Small delay to show the deleting state
            try? await Task.sleep(nanoseconds: 200_000_000)  // 0.2 seconds
            
            // Delete files
            try? fileManager.removeItem(at: Self.kokoroModelPath)
            try? fileManager.removeItem(at: Self.kokoroTokenizerPath)
            
            // Delete all voice files
            for voice in KokoroVoice.allCases {
                try? fileManager.removeItem(at: Self.kokoroVoicePath(for: voice))
            }
            
            // Update state
            kokoroStatus = .notDownloaded
            print("[ModelDownload] Kokoro model deleted successfully")
        }
    }
    
    func deletePiperModel(voice: PiperVoice) {
        let currentStatus = voice == .amy_medium ? piperAmyStatus : piperRyanStatus
        guard !currentStatus.isDeleting else { return }
        
        updatePiperStatus(voice: voice, status: .deleting)
        print("[ModelDownload] Deleting Piper \(voice.displayName)...")
        
        Task {
            // Small delay to show the deleting state
            try? await Task.sleep(nanoseconds: 200_000_000)  // 0.2 seconds
            
            // Delete files
            try? fileManager.removeItem(at: Self.piperModelPath(for: voice))
            try? fileManager.removeItem(at: Self.piperConfigPath(for: voice))
            
            // Update state
            updatePiperStatus(voice: voice, status: .notDownloaded)
            print("[ModelDownload] Piper \(voice.displayName) deleted successfully")
        }
    }
    
    /// Delete all Piper models
    func deleteAllPiperModels() {
        for voice in PiperVoice.allCases {
            deletePiperModel(voice: voice)
        }
    }
    
    // MARK: - Generic Download Helper
    private func downloadFile(
        from url: URL,
        to destination: URL,
        taskId: String,
        progressHandler: @escaping (Double, Int64, Int64) -> Void
    ) async throws {
        // Remove existing file if present
        try? fileManager.removeItem(at: destination)
        
        return try await withCheckedThrowingContinuation { continuation in
            let task = session.downloadTask(with: url) { [weak self] tempURL, response, error in
                guard let self = self else {
                    continuation.resume(throwing: NSError(domain: "ModelDownload", code: -1, userInfo: [NSLocalizedDescriptionKey: "Manager deallocated"]))
                    return
                }
                
                // Clean up
                Task { @MainActor in
                    self.downloadTasks.removeValue(forKey: taskId)
                    self.progressObservers.removeValue(forKey: taskId)
                }
                
                if let error = error {
                    if (error as NSError).code == NSURLErrorCancelled {
                        continuation.resume(throwing: NSError(domain: "ModelDownload", code: -2, userInfo: [NSLocalizedDescriptionKey: "Download cancelled"]))
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }
                
                guard let tempURL = tempURL else {
                    continuation.resume(throwing: NSError(domain: "ModelDownload", code: -3, userInfo: [NSLocalizedDescriptionKey: "No file received"]))
                    return
                }
                
                // Check HTTP status
                if let httpResponse = response as? HTTPURLResponse {
                    guard httpResponse.statusCode == 200 else {
                        continuation.resume(throwing: NSError(domain: "ModelDownload", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP error: \(httpResponse.statusCode)"]))
                        return
                    }
                }
                
                // Move to destination
                do {
                    try self.fileManager.moveItem(at: tempURL, to: destination)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            
            // Observe progress
            let observation = task.progress.observe(\.fractionCompleted) { progress, _ in
                let downloaded = task.countOfBytesReceived
                let total = task.countOfBytesExpectedToReceive
                progressHandler(progress.fractionCompleted, downloaded, total)
            }
            
            Task { @MainActor in
                self.downloadTasks[taskId] = task
                self.progressObservers[taskId] = observation
            }
            
            task.resume()
        }
    }
    
    // MARK: - Utility
    nonisolated static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
