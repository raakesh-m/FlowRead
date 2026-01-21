// FlowReadApp.swift
// FlowRead - A native macOS PDF Reader with Text-to-Speech
// Created for distraction-free reading with Groq TTS integration

import SwiftUI

@main
struct FlowReadApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 800, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open PDF...") {
                    NotificationCenter.default.post(name: .openPDF, object: nil)
                }
                .keyboardShortcut("o", modifiers: .command)
            }
            
            CommandGroup(after: .appSettings) {
                Button("Preferences...") {
                    NotificationCenter.default.post(name: .openPreferences, object: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            
            CommandMenu("Playback") {
                Button("Play/Pause") {
                    NotificationCenter.default.post(name: .togglePlayback, object: nil)
                }
                .keyboardShortcut(" ", modifiers: [])
                
                Button("Next Sentence") {
                    NotificationCenter.default.post(name: .nextChunk, object: nil)
                }
                .keyboardShortcut(.rightArrow, modifiers: .command)
                
                Button("Previous Sentence") {
                    NotificationCenter.default.post(name: .previousChunk, object: nil)
                }
                .keyboardShortcut(.leftArrow, modifiers: .command)
                
                Divider()
                
                Button("Increase Speed") {
                    NotificationCenter.default.post(name: .increaseSpeed, object: nil)
                }
                .keyboardShortcut("+", modifiers: .command)
                
                Button("Decrease Speed") {
                    NotificationCenter.default.post(name: .decreaseSpeed, object: nil)
                }
                .keyboardShortcut("-", modifiers: .command)
            }
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let openPDF = Notification.Name("openPDF")
    static let openPreferences = Notification.Name("openPreferences")
    static let togglePlayback = Notification.Name("togglePlayback")
    static let nextChunk = Notification.Name("nextChunk")
    static let previousChunk = Notification.Name("previousChunk")
    static let increaseSpeed = Notification.Name("increaseSpeed")
    static let decreaseSpeed = Notification.Name("decreaseSpeed")
}
