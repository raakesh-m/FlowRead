// AppState.swift
// FlowRead - Central application state management

import SwiftUI
import Combine
import PDFKit

/// Central application state manager
@MainActor
class AppState: ObservableObject {
    // MARK: - PDF State
    @Published var pdfDocument: PDFDocument?
    @Published var pdfURL: URL?
    @Published var textChunks: [TextChunk] = []
    @Published var currentChunkIndex: Int = 0
    
    // MARK: - Playback State
    @Published var isPlaying: Bool = false
    @Published var playbackSpeed: Double = 1.0
    @Published var isLoading: Bool = false
    @Published var loadingMessage: String = ""
    
    // MARK: - UI State
    @Published var autoScrollEnabled: Bool = true
    @Published var showPreferences: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    @Published var isTTSEnabled: Bool = true
    @Published var fontSize: Double = 17.0
    @Published var lineSpacing: Double = 10.0
    @Published var selectedVoice: String = GroqVoice.hannah.rawValue
    
    // MARK: - TTS Engine State
    @Published var selectedTTSEngine: TTSEngine = .macOSNative
    @Published var selectedNativeVoice: NativeVoice = .samantha
    @Published var selectedKokoroVoice: KokoroVoice = .af_bella
    @Published var selectedPiperVoice: PiperVoice = .amy_medium
    
    // MARK: - Services
    let audioManager: AudioPlaybackManager
    let ttsService: GroqTTSService
    let ttsManager: TTSManager
    let persistenceManager: PersistenceManager
    let pdfProcessor: PDFTextProcessor
    let modelDownloadManager: ModelDownloadManager
    
    // MARK: - Cancellables
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Audio Cache (for pre-fetching)
    private var audioCache: [Int: Data] = [:]  // Maps chunk index to audio data
    
    // MARK: - Speed Presets
    static let speedPresets: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]
    
    init() {
        logInfo("AppState initialization starting...")

        do {
            logDebug("Initializing AudioPlaybackManager...")
            self.audioManager = AudioPlaybackManager()

            logDebug("Initializing GroqTTSService...")
            self.ttsService = GroqTTSService()

            logDebug("Initializing TTSManager...")
            self.ttsManager = TTSManager(groqService: ttsService)

            logDebug("Initializing PersistenceManager...")
            self.persistenceManager = PersistenceManager()

            logDebug("Initializing PDFTextProcessor...")
            self.pdfProcessor = PDFTextProcessor()

            logDebug("Initializing ModelDownloadManager...")
            self.modelDownloadManager = ModelDownloadManager()

            logInfo("All services initialized successfully")

            logDebug("Setting up bindings...")
            setupBindings()

            logDebug("Loading persisted state...")
            loadPersistedState()

            logInfo("AppState initialization complete")
        } catch {
            logCritical("AppState initialization failed: \(error.localizedDescription)")
            fatalError("Failed to initialize AppState: \(error)")
        }
    }
    
    private func setupBindings() {
        // Listen for audio completion
        audioManager.$currentChunkCompleted
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completed in
                if completed {
                    self?.onChunkCompleted()
                }
            }
            .store(in: &cancellables)
        
        // Sync playback speed with audio manager
        $playbackSpeed
            .sink { [weak self] speed in
                self?.audioManager.setPlaybackSpeed(speed)
            }
            .store(in: &cancellables)
    }
    
    private func loadPersistedState() {
        let state = persistenceManager.loadState()
        
        self.playbackSpeed = state.playbackSpeed
        self.autoScrollEnabled = state.autoScrollEnabled
        self.isTTSEnabled = state.isTTSEnabled
        
        if let size = state.fontSize {
            self.fontSize = size
        }
        
        if let spacing = state.lineSpacing {
            self.lineSpacing = spacing
        }
        
        if let voiceID = state.selectedVoice {
            self.selectedVoice = voiceID
            Task {
                if let voice = GroqVoice(rawValue: voiceID) {
                    await ttsService.setVoice(voice)
                }
            }
        }
        
        // Load TTS Engine settings
        if let engineID = state.selectedTTSEngine, let engine = TTSEngine(rawValue: engineID) {
            self.selectedTTSEngine = engine
            ttsManager.setEngine(engine)
        }
        
        if let nativeVoiceID = state.selectedNativeVoice, let voice = NativeVoice(rawValue: nativeVoiceID) {
            self.selectedNativeVoice = voice
            ttsManager.setNativeVoice(voice)
        }
        
        if let kokoroVoiceID = state.selectedKokoroVoice, let voice = KokoroVoice(rawValue: kokoroVoiceID) {
            self.selectedKokoroVoice = voice
            ttsManager.setKokoroVoice(voice)
        }
        
        if let piperVoiceID = state.selectedPiperVoice, let voice = PiperVoice(rawValue: piperVoiceID) {
            self.selectedPiperVoice = voice
            ttsManager.setPiperVoice(voice)
        }
        
        // Restore last opened PDF using security-scoped bookmark
        Task {
            if let restoredURL = await restoreLastPDF(from: state) {
                await loadPDF(from: restoredURL, showError: false, isRestoring: true)
                if let position = state.lastReadingPosition {
                    // Ensure position is valid after loading
                    if !textChunks.isEmpty {
                        self.currentChunkIndex = min(max(0, position), textChunks.count - 1)
                    }
                }
            }
        }
    }
    
    /// Restore PDF access from security-scoped bookmark
    private func restoreLastPDF(from state: PersistedState) async -> URL? {
        // Try security-scoped bookmark first (best method)
        if let bookmarkData = state.lastPDFBookmark {
            do {
                var isStale = false
                let url = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                
                // Start accessing the security-scoped resource
                if url.startAccessingSecurityScopedResource() {
                    print("[Session] Restored PDF from bookmark: \(url.lastPathComponent)")
                    
                    // If bookmark is stale, we'll create a new one when saving
                    if isStale {
                        print("[Session] Bookmark was stale, will refresh on save")
                    }
                    
                    return url
                }
            } catch {
                print("[Session] Failed to resolve bookmark: \(error)")
            }
        }
        
        // Fallback: Try the path directly (works for non-sandboxed or if file is in accessible location)
        if let lastPDFPath = state.lastPDFPath,
           let url = URL(string: lastPDFPath),
           FileManager.default.fileExists(atPath: url.path) {
            print("[Session] Trying direct path: \(url.lastPathComponent)")
            return url
        }
        
        return nil
    }
    
    func saveState() {
        // Create security-scoped bookmark for the PDF
        var bookmarkData: Data? = nil
        if let url = pdfURL {
            do {
                bookmarkData = try url.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                print("[Session] Created bookmark for: \(url.lastPathComponent)")
            } catch {
                print("[Session] Failed to create bookmark: \(error)")
            }
        }
        
        let state = PersistedState(
            lastPDFPath: pdfURL?.absoluteString,
            lastPDFBookmark: bookmarkData,
            lastReadingPosition: currentChunkIndex,
            playbackSpeed: playbackSpeed,
            autoScrollEnabled: autoScrollEnabled,
            selectedVoice: selectedVoice,
            fontSize: fontSize,
            lineSpacing: lineSpacing,
            isTTSEnabled: isTTSEnabled,
            selectedTTSEngine: selectedTTSEngine.rawValue,
            selectedNativeVoice: selectedNativeVoice.rawValue,
            selectedKokoroVoice: selectedKokoroVoice.rawValue,
            selectedPiperVoice: selectedPiperVoice.rawValue
        )
        persistenceManager.saveState(state)
    }
    
    // MARK: - PDF Loading
    func loadPDF(from url: URL, showError: Bool = true, isRestoring: Bool = false) async {
        isLoading = true
        loadingMessage = "Loading PDF..."
        
        guard let document = PDFDocument(url: url) else {
            if showError {
                showErrorMessage("Unable to load PDF. The file may be corrupted or unsupported.")
            }
            isLoading = false
            return
        }
        
        self.pdfDocument = document
        self.pdfURL = url
        
        loadingMessage = "Extracting text..."
        
        do {
            let chunks = try await pdfProcessor.extractTextChunks(from: document)
            self.textChunks = chunks
            
            // Only reset position if not restoring
            if !isRestoring {
                self.currentChunkIndex = 0
            }
            
            self.audioCache.removeAll()  // Clear cache for new document
            
            if chunks.isEmpty {
                showErrorMessage("No readable text found in this PDF.")
            }
        } catch {
            showErrorMessage("Failed to extract text: \(error.localizedDescription)")
        }
        
        isLoading = false
        loadingMessage = ""
        
        // Save state (creates new bookmark)
        if !isRestoring {
            saveState()
        }
    }
    
    // MARK: - Playback Controls
    func togglePlayback() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    func play() {
        guard !textChunks.isEmpty else { return }
        
        isPlaying = true
        speakCurrentChunk()
    }
    
    func pause() {
        isPlaying = false
        audioManager.pause()
    }
    
    func stop() {
        isPlaying = false
        audioManager.stop()
    }
    
    func nextChunk() {
        guard currentChunkIndex < textChunks.count - 1 else {
            stop()
            return
        }
        
        audioManager.stop()
        currentChunkIndex += 1
        
        if isPlaying {
            speakCurrentChunk()
        }
        
        saveState()
    }
    
    func previousChunk() {
        guard currentChunkIndex > 0 else { return }
        
        audioManager.stop()
        currentChunkIndex -= 1
        
        if isPlaying {
            speakCurrentChunk()
        }
        
        saveState()
    }
    
    func jumpToChunk(_ index: Int) {
        guard index >= 0 && index < textChunks.count else { return }
        
        audioManager.stop()
        currentChunkIndex = index
        
        if isPlaying {
            speakCurrentChunk()
        }
        
        saveState()
    }
    
    private func speakCurrentChunk() {
        guard currentChunkIndex < textChunks.count else {
            stop()
            return
        }
        
        let chunk = textChunks[currentChunkIndex]
        
        Task {
            // Handle Non-TTS Mode (Visual Only)
            if !isTTSEnabled {
                let charCount = chunk.text.count
                // Approx 15 chars per second normal speed
                let seconds = Double(charCount) / (15.0 * playbackSpeed)
                let nanoseconds = UInt64(max(seconds, 1.0) * 1_000_000_000)
                
                try? await Task.sleep(nanoseconds: nanoseconds)
                
                if isPlaying {
                    onChunkCompleted()
                }
                return
            }
            
            // Check if we already have cached audio for this chunk
            if let cachedAudio = audioCache[currentChunkIndex] {
                await audioManager.play(audioData: cachedAudio)
                // Pre-fetch next chunks in background
                prefetchUpcomingChunks()
                return
            }
        
            do {
                // Check if text is valid before showing loading
                let isValid = ttsManager.isValidForTTS(chunk.text)
                
                if !isValid {
                    // Skip this chunk silently and move to next
                    print("[TTS] Skipping invalid chunk \(currentChunkIndex): '\(chunk.text.prefix(20))...'")
                    if isPlaying && currentChunkIndex < textChunks.count - 1 {
                        currentChunkIndex += 1
                        speakCurrentChunk()
                    } else {
                        stop()
                    }
                    return
                }
                
                // Only show loading if not cached
                isLoading = true
                loadingMessage = "Generating audio (\(selectedTTSEngine.displayName))..."
                
                // Use TTSManager to synthesize using the selected engine
                let audioData = try await ttsManager.synthesize(text: chunk.text)
                
                isLoading = false
                loadingMessage = ""
                
                // Handle nil return (invalid text was detected during processing)
                guard let audio = audioData else {
                    // Skip this chunk and move to next
                    print("[TTS] Synthesize returned nil, skipping chunk")
                    if isPlaying && currentChunkIndex < textChunks.count - 1 {
                        currentChunkIndex += 1
                        speakCurrentChunk()
                    } else {
                        stop()
                    }
                    return
                }
                
                // Cache and play
                audioCache[currentChunkIndex] = audio
                await audioManager.play(audioData: audio)
                
                // Pre-fetch next chunks in background
                prefetchUpcomingChunks()
                
            } catch let error as GroqTTSError {
                isLoading = false
                loadingMessage = ""
                handleTTSError(error)
            } catch let error as NativeTTSError {
                isLoading = false
                loadingMessage = ""
                showErrorMessage("Native TTS error: \(error.localizedDescription)")
            } catch {
                isLoading = false
                loadingMessage = ""
                showErrorMessage("Audio generation failed: \(error.localizedDescription)")
            }
        }
    }
    
    /// Pre-fetch audio for upcoming chunks in background
    private func prefetchUpcomingChunks() {
        let chunksToPreFetch = 3  // Pre-fetch next 3 chunks
        
        Task { [weak self] in
            guard let self = self else { return }
            
            for offset in 1...chunksToPreFetch {
                let index = self.currentChunkIndex + offset
                let chunks = self.textChunks
                
                // Check bounds
                guard index < chunks.count else { break }
                
                // Skip if already cached
                let isCached = self.audioCache[index] != nil
                if isCached { continue }
                
                // Skip if not valid
                let text = chunks[index].text
                let isValid = self.ttsManager.isValidForTTS(text)
                guard isValid else { continue }
                
                // Synthesize in background using TTSManager
                do {
                    if let audio = try await self.ttsManager.synthesize(text: text) {
                        self.audioCache[index] = audio
                        print("[TTS Prefetch] Cached chunk \(index)")
                    }
                } catch {
                    print("[TTS Prefetch] Failed for chunk \(index): \(error.localizedDescription)")
                    // Don't propagate errors from prefetch - it's optional optimization
                }
            }
        }
    }
    
    private func onChunkCompleted() {
        guard isPlaying else { return }
        
        if currentChunkIndex < textChunks.count - 1 {
            currentChunkIndex += 1
            speakCurrentChunk()
            saveState()
        } else {
            stop()
        }
    }
    
    private func handleTTSError(_ error: GroqTTSError) {
        switch error {
        case .allKeysExhausted:
            showErrorMessage("All API keys have been exhausted. Please check your API key configuration.")
            stop()
        case .rateLimited:
            showErrorMessage("Rate limit reached. Switching to next API key...")
            // The TTS service handles key rotation internally
            speakCurrentChunk()
        case .networkError(let message):
            showErrorMessage("Network error: \(message)")
            pause()
        case .invalidResponse:
            showErrorMessage("Invalid response from TTS service. Retrying...")
            speakCurrentChunk()
        case .invalidAudioData:
            showErrorMessage("Invalid audio data received. Retrying...")
            speakCurrentChunk()
        case .noAPIKeysConfigured:
            showErrorMessage("No API keys configured. Please add your Groq API keys in preferences.")
            stop()
        }
    }
    
    // MARK: - Speed Control
    func increaseSpeed() {
        if let currentIndex = Self.speedPresets.firstIndex(of: playbackSpeed),
           currentIndex < Self.speedPresets.count - 1 {
            playbackSpeed = Self.speedPresets[currentIndex + 1]
        } else if playbackSpeed < Self.speedPresets.last! {
            playbackSpeed = Self.speedPresets.first { $0 > playbackSpeed } ?? playbackSpeed
        }
        saveState()
    }
    
    func decreaseSpeed() {
        if let currentIndex = Self.speedPresets.firstIndex(of: playbackSpeed),
           currentIndex > 0 {
            playbackSpeed = Self.speedPresets[currentIndex - 1]
        } else if playbackSpeed > Self.speedPresets.first! {
            playbackSpeed = Self.speedPresets.last { $0 < playbackSpeed } ?? playbackSpeed
        }
        saveState()
    }
    
    func resetSpeed() {
        playbackSpeed = 1.0
        saveState()
    }
    
    // MARK: - Feature Toggles
    func toggleAutoScroll() {
        autoScrollEnabled.toggle()
        saveState()
    }
    
    func toggleTTS() {
        isTTSEnabled.toggle()
        saveState()
    }
    
    // MARK: - Navigation
    func jumpToBeginning() {
        guard !textChunks.isEmpty else { return }
        
        audioManager.stop()
        currentChunkIndex = 0
        
        if isPlaying {
            speakCurrentChunk()
        }
        
        saveState()
    }
    
    func jumpToEnd() {
        guard !textChunks.isEmpty else { return }
        
        audioManager.stop()
        currentChunkIndex = textChunks.count - 1
        
        if isPlaying {
            speakCurrentChunk()
        }
        
        saveState()
    }
    
    // MARK: - Font Size Controls
    func increaseFontSize() {
        fontSize = min(fontSize + 2, 32)  // Max 32pt
        saveState()
    }
    
    func decreaseFontSize() {
        fontSize = max(fontSize - 2, 12)  // Min 12pt
        saveState()
    }
    
    func resetFontSize() {
        fontSize = 17.0  // Default
        saveState()
    }
    
    // MARK: - Error Handling
    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
    }
    
    func dismissError() {
        showError = false
        errorMessage = nil
    }
    
    // MARK: - Settings Actions
    func reloadKeys() {
        Task {
            await ttsService.reloadKeys()
        }
    }
    
    func updateVoice(_ voice: GroqVoice) {
        selectedVoice = voice.rawValue
        Task {
            await ttsService.setVoice(voice)
            saveState()
        }
    }
    
    // MARK: - TTS Engine Management
    
    func updateTTSEngine(_ engine: TTSEngine) {
        selectedTTSEngine = engine
        audioCache.removeAll()  // Clear cache when switching engines
        ttsManager.setEngine(engine)
        saveState()
    }
    
    func updateNativeVoice(_ voice: NativeVoice) {
        selectedNativeVoice = voice
        audioCache.removeAll()  // Clear cache when switching voices
        ttsManager.setNativeVoice(voice)
        saveState()
    }
    
    func updateKokoroVoice(_ voice: KokoroVoice) {
        selectedKokoroVoice = voice
        audioCache.removeAll()
        ttsManager.setKokoroVoice(voice)
        saveState()
    }
    
    func updatePiperVoice(_ voice: PiperVoice) {
        selectedPiperVoice = voice
        audioCache.removeAll()
        ttsManager.setPiperVoice(voice)
        saveState()
    }
    
    /// Check if current TTS engine is ready to use
    func isTTSEngineReady() -> Bool {
        return ttsManager.isEngineReady()
    }
    
    /// Get status message for current TTS engine
    func getTTSEngineStatus() -> String {
        return ttsManager.getEngineStatus()
    }
}
