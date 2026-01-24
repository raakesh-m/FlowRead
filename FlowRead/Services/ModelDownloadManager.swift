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
    @Published var piperStatus: ModelDownloadStatus = .notDownloaded
    
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
        if !piperStatus.isDownloading && !piperStatus.isDeleting {
             piperStatus = .notDownloaded
         }
         
         // Check Kokoro - need model, tokenizer, and at least one voice
         let kokoroModelExists = fileManager.fileExists(atPath: Self.kokoroModelPath.path)
         let kokoroTokenizerExists = fileManager.fileExists(atPath: Self.kokoroTokenizerPath.path)
         let kokoroVoiceExists = fileManager.fileExists(atPath: Self.kokoroVoicePath(for: .af_bella).path)
         
         print("[ModelDownload] Kokoro: model=\(kokoroModelExists), tokenizer=\(kokoroTokenizerExists), voice=\(kokoroVoiceExists)")
         
         if kokoroModelExists && kokoroTokenizerExists && kokoroVoiceExists {
             kokoroStatus = .downloaded
         }
         
         // Check Piper - need ALL voices for "Pack" status
         var allPiperVoicesExist = true
         for voice in PiperVoice.allCases {
             let modelExists = fileManager.fileExists(atPath: Self.piperModelPath(for: voice).path)
             let configExists = fileManager.fileExists(atPath: Self.piperConfigPath(for: voice).path)
             if !modelExists || !configExists {
                 allPiperVoicesExist = false
                 break
             }
         }
         
         print("[ModelDownload] Piper Pack: exists=\(allPiperVoicesExist)")
         if allPiperVoicesExist {
             piperStatus = .downloaded
         }
         
         print("[ModelDownload] Status check complete - Kokoro: \(kokoroStatus), Piper: \(piperStatus)")
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
        objectWillChange.send()
        
        do {
            // Download model file (~93 MB - 90% of total)
            print("[ModelDownload] Starting Kokoro model download...")
            try await downloadFile(
                from: KokoroModelURLs.modelURL,
                to: Self.kokoroModelPath,
                taskId: "kokoro_model"
            ) { [weak self] progress, downloaded, _ in
                DispatchQueue.main.async {
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
            ) { [weak self] progress, downloaded, _ in
                DispatchQueue.main.async {
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
            ) { [weak self] progress, downloaded, _ in
                DispatchQueue.main.async {
                    let overallProgress = 0.97 + (progress * 0.03)
                    let overallDownloaded = KokoroModelURLs.modelSize + KokoroModelURLs.tokenizerSize + downloaded
                    self?.kokoroStatus = .downloading(progress: overallProgress, bytesDownloaded: overallDownloaded, totalBytes: totalSize)
                }
            }
            
            // Small delay to let any pending progress updates complete
            try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds
            
            // Verify files exist before marking as downloaded
            let modelExists = fileManager.fileExists(atPath: Self.kokoroModelPath.path)
            let tokenizerExists = fileManager.fileExists(atPath: Self.kokoroTokenizerPath.path)
            let voiceExists = fileManager.fileExists(atPath: Self.kokoroVoicePath(for: defaultVoice).path)
            
            if modelExists && tokenizerExists && voiceExists {
                kokoroStatus = .downloaded
                objectWillChange.send()
                print("[ModelDownload] Kokoro model downloaded successfully!")
            } else {
                kokoroStatus = .failed(error: "Download completed but files not found")
                print("[ModelDownload] Kokoro download verification failed")
            }
            
        } catch {
            kokoroStatus = .failed(error: error.localizedDescription)
            objectWillChange.send()
            print("[ModelDownload] Kokoro download failed: \(error)")
        }
    }
    
    // MARK: - Download Piper Model
    // MARK: - Download Piper Pack
    private var piperBytesReceived: [String: Int64] = [:]
    
    func downloadPiperPack() async {
        guard !piperStatus.isDownloading && !piperStatus.isDownloaded else { return }
        
        do {
            try ensureModelsDirectory()
        } catch {
            piperStatus = .failed(error: "Failed to create directory: \(error.localizedDescription)")
            return
        }
        
        let totalPackSize = PiperVoice.allCases.reduce(0) { $0 + $1.downloadSize }
        piperStatus = .downloading(progress: 0, bytesDownloaded: 0, totalBytes: totalPackSize)
        objectWillChange.send()
        
        piperBytesReceived.removeAll()
        
        await withTaskGroup(of: Void.self) { group in
            for voice in PiperVoice.allCases {
                // model
                group.addTask {
                    try? await self.downloadFile(
                        from: voice.modelURL,
                        to: Self.piperModelPath(for: voice),
                        taskId: "piper_\(voice.rawValue)_model"
                    ) { [weak self] _, downloaded, _ in
                        Task { @MainActor in
                            self?.updatePiperPackProgress(taskId: "piper_\(voice.rawValue)_model", downloaded: downloaded, totalPackSize: totalPackSize)
                        }
                    }
                }
                
                // config
                group.addTask {
                    try? await self.downloadFile(
                        from: voice.configURL,
                        to: Self.piperConfigPath(for: voice),
                        taskId: "piper_\(voice.rawValue)_config"
                    ) { [weak self] _, downloaded, _ in
                        Task { @MainActor in
                            self?.updatePiperPackProgress(taskId: "piper_\(voice.rawValue)_config", downloaded: downloaded, totalPackSize: totalPackSize)
                        }
                    }
                }
            }
        }
        
        // Small delay
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // Verify ALL files
        var allExist = true
        for voice in PiperVoice.allCases {
            if !fileManager.fileExists(atPath: Self.piperModelPath(for: voice).path) ||
               !fileManager.fileExists(atPath: Self.piperConfigPath(for: voice).path) {
                allExist = false
                break
            }
        }
        
        if allExist {
            piperStatus = .downloaded
            print("[ModelDownload] Piper Pack downloaded successfully!")
        } else {
            piperStatus = .failed(error: "Download incomplete")
            print("[ModelDownload] Piper Pack verification failed")
        }
    }
    
    private func updatePiperPackProgress(taskId: String, downloaded: Int64, totalPackSize: Int64) {
        piperBytesReceived[taskId] = downloaded
        let totalDownloaded = piperBytesReceived.values.reduce(0, +)
        let progress = Double(totalDownloaded) / Double(totalPackSize)
        piperStatus = .downloading(progress: progress, bytesDownloaded: totalDownloaded, totalBytes: totalPackSize)
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
    
    // MARK: - Cancel Piper Pack
    func cancelPiperPackDownload() {
        for voice in PiperVoice.allCases {
            cancelDownload(taskId: "piper_\(voice.rawValue)_model")
            cancelDownload(taskId: "piper_\(voice.rawValue)_config")
        }
        piperBytesReceived.removeAll()
        piperStatus = .notDownloaded
    }

    // MARK: - Delete Kokoro Model
    func deleteKokoroModel() {
        guard !kokoroStatus.isDeleting else { 
            print("[ModelDownload] Already deleting Kokoro, ignoring")
            return 
        }
        
        print("[ModelDownload] Starting Kokoro model deletion...")
        kokoroStatus = .deleting
        objectWillChange.send()
        
        // Use regular Task to maintain MainActor context
        Task {
            // Small delay to allow UI to show deleting state
            try? await Task.sleep(nanoseconds: 300_000_000)  // 0.3 seconds
            
            // Delete files on background thread
            await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    let fm = FileManager.default
                    
                    // Delete model file
                    if fm.fileExists(atPath: Self.kokoroModelPath.path) {
                        do {
                            try fm.removeItem(at: Self.kokoroModelPath)
                            print("[ModelDownload] Deleted: \(Self.kokoroModelPath.lastPathComponent)")
                        } catch {
                            print("[ModelDownload] Failed to delete model: \(error)")
                        }
                    }
                    
                    // Delete tokenizer file
                    if fm.fileExists(atPath: Self.kokoroTokenizerPath.path) {
                        do {
                            try fm.removeItem(at: Self.kokoroTokenizerPath)
                            print("[ModelDownload] Deleted: \(Self.kokoroTokenizerPath.lastPathComponent)")
                        } catch {
                            print("[ModelDownload] Failed to delete tokenizer: \(error)")
                        }
                    }
                    
                    // Delete all voice files
                    for voice in KokoroVoice.allCases {
                        let voicePath = Self.kokoroVoicePath(for: voice)
                        if fm.fileExists(atPath: voicePath.path) {
                            try? fm.removeItem(at: voicePath)
                        }
                    }
                    
                    continuation.resume()
                }
            }
            
            // Update status on MainActor
            kokoroStatus = .notDownloaded
            objectWillChange.send()
            print("[ModelDownload] Kokoro model deleted successfully")
        }
    }

    // MARK: - Delete Piper Pack
    func deletePiperPack() {
        guard !piperStatus.isDeleting else { return }
        
        print("[ModelDownload] Starting Piper Pack deletion...")
        piperStatus = .deleting
        objectWillChange.send()
        
        Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            
            await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    let fm = FileManager.default
                    
                    for voice in PiperVoice.allCases {
                        let model = Self.piperModelPath(for: voice)
                        let config = Self.piperConfigPath(for: voice)
                        
                        try? fm.removeItem(at: model)
                        try? fm.removeItem(at: config)
                    }
                    continuation.resume()
                }
            }
            
            piperStatus = .notDownloaded
            print("[ModelDownload] Piper Pack deleted successfully")
            objectWillChange.send()
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
            
            // Observe progress BEFORE resuming task
            let observation = task.progress.observe(\.fractionCompleted, options: [.new]) { [weak task] progress, _ in
                guard let task = task else { return }
                let downloaded = task.countOfBytesReceived
                let total = max(task.countOfBytesExpectedToReceive, 1)  // Avoid division by zero
                let fraction = total > 0 ? Double(downloaded) / Double(total) : progress.fractionCompleted
                
                // Dispatch to main thread for UI updates
                DispatchQueue.main.async {
                    progressHandler(fraction, downloaded, total)
                }
            }
            
            // Store task and observation
            self.downloadTasks[taskId] = task
            self.progressObservers[taskId] = observation
            
            // Start the download
            task.resume()
            print("[ModelDownload] Task \(taskId) started")
        }
    }
    
    // MARK: - Utility
    nonisolated static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
