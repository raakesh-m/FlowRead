// AudioPlaybackManager.swift
// FlowRead - Native macOS audio playback management

import Foundation
import AVFoundation
import Combine

/// Manages audio playback with native AVFoundation
@MainActor
class AudioPlaybackManager: NSObject, ObservableObject {
    @Published var isPlaying: Bool = false
    @Published var currentChunkCompleted: Bool = false
    @Published var playbackProgress: Double = 0.0
    @Published var duration: TimeInterval = 0
    
    private var audioPlayer: AVAudioPlayer?
    private var playbackRate: Float = 1.0
    private var progressTimer: Timer?
    
    override init() {
        super.init()
    }
    
    /// Play audio from Data
    func play(audioData: Data) async {
        do {
            currentChunkCompleted = false
            
            // Create player from data
            audioPlayer = try AVAudioPlayer(data: audioData)
            audioPlayer?.delegate = self
            audioPlayer?.enableRate = true
            audioPlayer?.rate = playbackRate
            audioPlayer?.prepareToPlay()
            
            duration = audioPlayer?.duration ?? 0
            
            audioPlayer?.play()
            isPlaying = true
            
            startProgressTimer()
        } catch {
            print("Failed to play audio: \(error)")
            currentChunkCompleted = true
        }
    }
    
    /// Pause playback
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        stopProgressTimer()
    }
    
    /// Resume playback
    func resume() {
        audioPlayer?.play()
        isPlaying = true
        startProgressTimer()
    }
    
    /// Stop playback
    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        playbackProgress = 0
        stopProgressTimer()
    }
    
    /// Set playback speed
    func setPlaybackSpeed(_ speed: Double) {
        playbackRate = Float(speed)
        audioPlayer?.rate = playbackRate
    }
    
    /// Seek to position (0.0 - 1.0)
    func seek(to position: Double) {
        guard let player = audioPlayer else { return }
        let time = position * player.duration
        player.currentTime = time
    }
    
    private func startProgressTimer() {
        stopProgressTimer()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateProgress()
            }
        }
    }
    
    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
    
    private func updateProgress() {
        guard let player = audioPlayer, player.duration > 0 else {
            playbackProgress = 0
            return
        }
        playbackProgress = player.currentTime / player.duration
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioPlaybackManager: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            isPlaying = false
            playbackProgress = 1.0
            currentChunkCompleted = true
            stopProgressTimer()
        }
    }
    
    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            print("Audio decode error: \(error?.localizedDescription ?? "unknown")")
            isPlaying = false
            currentChunkCompleted = true
            stopProgressTimer()
        }
    }
}
