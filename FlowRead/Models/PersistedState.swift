// PersistedState.swift
// FlowRead - Persistence model for app state

import Foundation

/// State that persists between app sessions
struct PersistedState: Codable {
    var lastPDFPath: String?
    var lastReadingPosition: Int?
    var playbackSpeed: Double
    var autoScrollEnabled: Bool
    var selectedVoice: String?
    var fontSize: Double?
    var lineSpacing: Double?
    
    init(
        lastPDFPath: String? = nil,
        lastReadingPosition: Int? = nil,
        playbackSpeed: Double = 1.0,
        autoScrollEnabled: Bool = true,
        selectedVoice: String? = nil,
        fontSize: Double? = nil,
        lineSpacing: Double? = nil
    ) {
        self.lastPDFPath = lastPDFPath
        self.lastReadingPosition = lastReadingPosition
        self.playbackSpeed = playbackSpeed
        self.autoScrollEnabled = autoScrollEnabled
        self.selectedVoice = selectedVoice
        self.fontSize = fontSize
        self.lineSpacing = lineSpacing
    }
    
    static let `default` = PersistedState()
}
