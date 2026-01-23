// PersistedState.swift
// FlowRead - Persistence model for app state

import Foundation

/// State that persists between app sessions
struct PersistedState: Codable {
    var lastPDFPath: String?
    var lastPDFBookmark: Data?  // Security-scoped bookmark for file access
    var lastReadingPosition: Int?
    var playbackSpeed: Double
    var autoScrollEnabled: Bool
    var selectedVoice: String?
    var fontSize: Double?
    var lineSpacing: Double?
    var isTTSEnabled: Bool
    
    init(
        lastPDFPath: String? = nil,
        lastPDFBookmark: Data? = nil,
        lastReadingPosition: Int? = nil,
        playbackSpeed: Double = 1.0,
        autoScrollEnabled: Bool = true,
        selectedVoice: String? = nil,
        fontSize: Double? = nil,
        lineSpacing: Double? = nil,
        isTTSEnabled: Bool = true
    ) {
        self.lastPDFPath = lastPDFPath
        self.lastPDFBookmark = lastPDFBookmark
        self.lastReadingPosition = lastReadingPosition
        self.playbackSpeed = playbackSpeed
        self.autoScrollEnabled = autoScrollEnabled
        self.selectedVoice = selectedVoice
        self.fontSize = fontSize
        self.lineSpacing = lineSpacing
        self.isTTSEnabled = isTTSEnabled
    }
    
    static let `default` = PersistedState()
}

