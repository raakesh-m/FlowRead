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
            // MARK: - File Menu
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
            
            // MARK: - Playback Menu
            CommandMenu("Playback") {
                Button("Play/Pause") {
                    NotificationCenter.default.post(name: .togglePlayback, object: nil)
                }
                .keyboardShortcut(" ", modifiers: [])
                
                Button("Stop") {
                    NotificationCenter.default.post(name: .stopPlayback, object: nil)
                }
                .keyboardShortcut(.escape, modifiers: [])
                
                Divider()
                
                Button("Next Sentence") {
                    NotificationCenter.default.post(name: .nextChunk, object: nil)
                }
                .keyboardShortcut(.rightArrow, modifiers: [])
                
                Button("Previous Sentence") {
                    NotificationCenter.default.post(name: .previousChunk, object: nil)
                }
                .keyboardShortcut(.leftArrow, modifiers: [])
                
                Divider()
                
                Button("Jump to Beginning") {
                    NotificationCenter.default.post(name: .jumpToBeginning, object: nil)
                }
                .keyboardShortcut(.upArrow, modifiers: .command)
                
                Button("Jump to End") {
                    NotificationCenter.default.post(name: .jumpToEnd, object: nil)
                }
                .keyboardShortcut(.downArrow, modifiers: .command)
                
                Divider()
                
                Button("Increase Speed") {
                    NotificationCenter.default.post(name: .increaseSpeed, object: nil)
                }
                .keyboardShortcut(.upArrow, modifiers: [])
                
                Button("Decrease Speed") {
                    NotificationCenter.default.post(name: .decreaseSpeed, object: nil)
                }
                .keyboardShortcut(.downArrow, modifiers: [])
                
                Button("Reset Speed (1.0x)") {
                    NotificationCenter.default.post(name: .resetSpeed, object: nil)
                }
                .keyboardShortcut("r", modifiers: [])
            }
            
            // MARK: - View Menu
            CommandMenu("View") {
                Button("Toggle Auto-Scroll") {
                    NotificationCenter.default.post(name: .toggleAutoScroll, object: nil)
                }
                .keyboardShortcut("a", modifiers: [])
                
                Button("Toggle Text-to-Speech") {
                    NotificationCenter.default.post(name: .toggleTTS, object: nil)
                }
                .keyboardShortcut("t", modifiers: [])
                
                Divider()
                
                Button("Increase Font Size") {
                    NotificationCenter.default.post(name: .increaseFontSize, object: nil)
                }
                .keyboardShortcut("=", modifiers: .command)
                
                Button("Decrease Font Size") {
                    NotificationCenter.default.post(name: .decreaseFontSize, object: nil)
                }
                .keyboardShortcut("-", modifiers: .command)
                
                Button("Reset Font Size") {
                    NotificationCenter.default.post(name: .resetFontSize, object: nil)
                }
                .keyboardShortcut("0", modifiers: .command)
            }
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    // File
    static let openPDF = Notification.Name("openPDF")
    static let openPreferences = Notification.Name("openPreferences")
    
    // Playback
    static let togglePlayback = Notification.Name("togglePlayback")
    static let stopPlayback = Notification.Name("stopPlayback")
    static let nextChunk = Notification.Name("nextChunk")
    static let previousChunk = Notification.Name("previousChunk")
    static let jumpToBeginning = Notification.Name("jumpToBeginning")
    static let jumpToEnd = Notification.Name("jumpToEnd")
    
    // Speed
    static let increaseSpeed = Notification.Name("increaseSpeed")
    static let decreaseSpeed = Notification.Name("decreaseSpeed")
    static let resetSpeed = Notification.Name("resetSpeed")
    
    // View
    static let toggleAutoScroll = Notification.Name("toggleAutoScroll")
    static let toggleTTS = Notification.Name("toggleTTS")
    static let increaseFontSize = Notification.Name("increaseFontSize")
    static let decreaseFontSize = Notification.Name("decreaseFontSize")
    static let resetFontSize = Notification.Name("resetFontSize")
}
