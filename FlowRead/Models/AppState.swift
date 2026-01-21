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
    
    // MARK: - Services
    let audioManager: AudioPlaybackManager
    let ttsService: GroqTTSService
    let persistenceManager: PersistenceManager
    let pdfProcessor: PDFTextProcessor
    
    // MARK: - Cancellables
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Speed Presets
    static let speedPresets: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]
    
    init() {
        self.audioManager = AudioPlaybackManager()
        self.ttsService = GroqTTSService()
        self.persistenceManager = PersistenceManager()
        self.pdfProcessor = PDFTextProcessor()
        
        setupBindings()
        loadPersistedState()
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
        
        // Restore last opened PDF if available
        if let lastPDFPath = state.lastPDFPath,
           let url = URL(string: lastPDFPath),
           FileManager.default.fileExists(atPath: url.path) {
            Task {
                await loadPDF(from: url, showError: false)
                if let position = state.lastReadingPosition {
                    self.currentChunkIndex = min(position, textChunks.count - 1)
                }
            }
        }
    }
    
    func saveState() {
        let state = PersistedState(
            lastPDFPath: pdfURL?.absoluteString,
            lastReadingPosition: currentChunkIndex,
            playbackSpeed: playbackSpeed,
            autoScrollEnabled: autoScrollEnabled
        )
        persistenceManager.saveState(state)
    }
    
    // MARK: - PDF Loading
    func loadPDF(from url: URL, showError: Bool = true) async {
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
            self.currentChunkIndex = 0
            
            if chunks.isEmpty {
                showErrorMessage("No readable text found in this PDF.")
            }
        } catch {
            showErrorMessage("Failed to extract text: \(error.localizedDescription)")
        }
        
        isLoading = false
        loadingMessage = ""
        saveState()
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
            do {
                isLoading = true
                loadingMessage = "Generating audio..."
                
                let audioData = try await ttsService.synthesize(text: chunk.text)
                
                isLoading = false
                loadingMessage = ""
                
                await audioManager.play(audioData: audioData)
            } catch let error as GroqTTSError {
                isLoading = false
                handleTTSError(error)
            } catch {
                isLoading = false
                showErrorMessage("Audio generation failed: \(error.localizedDescription)")
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
    
    // MARK: - Error Handling
    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
    }
    
    func dismissError() {
        showError = false
        errorMessage = nil
    }
}
