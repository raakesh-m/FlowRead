// PlaybackControlBar.swift
// FlowRead - Vibrant playback control bar

import SwiftUI

struct PlaybackControlBar: View {
    @EnvironmentObject var appState: AppState
    
    // Breakpoints for responsive design
    private let compactWidth: CGFloat = 600
    private let mediumWidth: CGFloat = 800
    
    var body: some View {
        GeometryReader { geometry in
            let isCompact = geometry.size.width < compactWidth
            let isMedium = geometry.size.width < mediumWidth
            
            HStack(spacing: isCompact ? 8 : (isMedium ? 12 : 24)) {
                // Left: Current chunk info (hide on very compact)
                if !isCompact {
                    CurrentChunkInfo(isCompact: isMedium)
                        .frame(maxWidth: isMedium ? 180 : 250, alignment: .leading)
                        .layoutPriority(-1)
                } else {
                    // Minimal placeholder for spacing
                    Spacer().frame(width: 8)
                }
                
                Spacer(minLength: 0)
                
                // Center: Playback controls (always visible)
                PlaybackControls(isCompact: isCompact)
                
                Spacer(minLength: 0)
                
                // Right: Controls (Speed, Voice) - TTS removed from here as per request
                HStack(spacing: isMedium ? 8 : 16) {
                    SpeedControl(isCompact: isMedium)
                    
                    // Unified Voice Picker (auto-detects engine)
                    UnifiedVoicePicker(isCompact: isMedium)
                }
                .layoutPriority(1)
            }
            .padding(.horizontal, isCompact ? 12 : (isMedium ? 16 : 28))
            .padding(.vertical, isCompact ? 16 : 24)
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .frame(height: 100) // Reduced height slightly for sleeker look
        .background(
            ZStack {
                Color(red: 0.10, green: 0.12, blue: 0.17)
                
                // Top border with subtle gradient glow
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [
                            Color(red: 0.36, green: 0.67, blue: 1.0).opacity(0.3),
                            Color(red: 0.69, green: 0.46, blue: 1.0).opacity(0.2),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(height: 1)
                    
                    Spacer()
                }
            }
        )
    }
}

// MARK: - Current Chunk Info

struct CurrentChunkInfo: View {
    @EnvironmentObject var appState: AppState
    var isCompact: Bool = false
    
    private var currentChunk: TextChunk? {
        let index = appState.currentChunkIndex
        guard index >= 0, index < appState.textChunks.count else { return nil }
        return appState.textChunks[index]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let chunk = currentChunk {
                HStack(spacing: 6) {
                    // Animated dot pulsates when playing
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.36, green: 0.67, blue: 1.0), Color(red: 0.69, green: 0.46, blue: 1.0)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 6, height: 6)
                        .scaleEffect(appState.isPlaying ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: appState.isPlaying)
                    
                    Text("PAGE \(chunk.pageIndex + 1)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color(red: 0.36, green: 0.67, blue: 1.0))
                        .textCase(.uppercase)
                        .tracking(1)
                }
                
                Text("#\(appState.currentChunkIndex + 1) • \(chunk.text.prefix(30))...")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(white: 0.6))
                    .lineLimit(1)
            } else {
                Text("Ready to Read")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(white: 0.4))
            }
        }
    }
}

// MARK: - Playback Controls

struct PlaybackControls: View {
    @EnvironmentObject var appState: AppState
    var isCompact: Bool = false
    
    var body: some View {
        HStack(spacing: isCompact ? 16 : 32) {
            // Prev
            ControlButton(
                icon: "backward.fill",
                size: isCompact ? 16 : 20,
                action: { appState.previousChunk() },
                disabled: appState.currentChunkIndex == 0
            )
            
            // Play/Pause with unique design
            PlayPauseButton(isCompact: isCompact)
            
            // Next
            ControlButton(
                icon: "forward.fill",
                size: isCompact ? 16 : 20,
                action: { appState.nextChunk() },
                disabled: appState.currentChunkIndex >= appState.textChunks.count - 1
            )
        }
    }
}

// MARK: - Modern Play/Pause Button

struct PlayPauseButton: View {
    @EnvironmentObject var appState: AppState
    var isCompact: Bool
    
    @State private var isHovered = false
    @State private var isPressed = false
    
    var body: some View {
        Button(action: { appState.togglePlayback() }) {
            ZStack {
                // Glow effect
                if appState.isPlaying {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(red: 0.36, green: 0.67, blue: 1.0).opacity(0.4),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 50
                            )
                        )
                        .frame(width: 80, height: 80)
                        .scaleEffect(isHovered ? 1.1 : 1.0)
                }
                
                // Button Body
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.36, green: 0.67, blue: 1.0),
                                Color(red: 0.20, green: 0.40, blue: 0.90) // Deeper blue
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: isCompact ? 48 : 64, height: isCompact ? 48 : 64)
                    .shadow(color: Color(red: 0.36, green: 0.67, blue: 1.0).opacity(0.4), radius: 10, y: 4)
                    .overlay(
                        Circle().stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                
                // Icon
                Image(systemName: appState.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: isCompact ? 20 : 28, weight: .bold))
                    .foregroundColor(.white)
                    .offset(x: appState.isPlaying ? 0 : 2) // Visual correction for play icon
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.95 : (isHovered ? 1.05 : 1.0))
        .animation(.spring(response: 0.3), value: isHovered)
        .animation(.spring(response: 0.1), value: isPressed)
        .onHover { isHovered = $0 }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Control Button

struct ControlButton: View {
    let icon: String
    let size: CGFloat
    let action: () -> Void
    var disabled: Bool = false
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .semibold))
                .foregroundColor(disabled ? Color.white.opacity(0.2) : (isHovered ? .white : Color.white.opacity(0.7)))
                .frame(width: size + 20, height: size + 20)
                .background(
                    Circle()
                        .fill(Color.white.opacity(isHovered && !disabled ? 0.1 : 0.0))
                )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .onHover { isHovered = $0 }
        .scaleEffect(isHovered && !disabled ? 1.1 : 1.0)
        .animation(.spring(response: 0.3), value: isHovered)
    }
}

// MARK: - Speed Control

struct SpeedControl: View {
    @EnvironmentObject var appState: AppState
    var isCompact: Bool
    @State private var isHovered = false
    @State private var showMenu = false
    
    var body: some View {
        Button(action: { showMenu.toggle() }) {
            HStack(spacing: 6) {
                Image(systemName: "gauge.with.needle")
                    .font(.system(size: 14))
                
                if !isCompact {
                    Text(String(format: "%.1fx", appState.playbackSpeed))
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                }
            }
            .foregroundColor(showMenu ? .white : (isHovered ? .white : Color(white: 0.7)))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(showMenu || isHovered ? 0.1 : 0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .popover(isPresented: $showMenu) {
            SpeedPickerPopover()
        }
        .help("Playback Speed")
    }
}

// MARK: - Unified Voice Picker (Engine Aware)

struct UnifiedVoicePicker: View {
    @EnvironmentObject var appState: AppState
    var isCompact: Bool
    @State private var isHovered = false
    @State private var showMenu = false
    
    // Determine info based on selected engine
    var currentInfo: (icon: String, name: String, color: Color) {
        switch appState.selectedTTSEngine {
        case .macOSNative:
            return ("laptopcomputer", appState.selectedNativeVoice.displayName, .blue)
        case .groqAPI:
            guard let voice = GroqVoice(rawValue: appState.selectedVoice) else { return ("cloud.fill", "Groq", .purple) }
            return ("cloud.bolt.fill", voice.displayName, Color(red: 0.69, green: 0.46, blue: 1.0))
        case .openAI:
            return ("OpenAILogo", "OpenAI", Color(red: 0.4, green: 0.8, blue: 0.6))  // Custom asset
        case .piper:
            return ("waveform.path.ecg", appState.selectedPiperVoice.displayName, .green)
        }
    }
    
    // Check if we're using a custom image asset
    var isCustomAsset: Bool {
        appState.selectedTTSEngine == .openAI
    }

    var body: some View {
        Button(action: { showMenu.toggle() }) {
            HStack(spacing: 8) {
                // Engine Icon
                ZStack {
                    Circle()
                        .fill(currentInfo.color.opacity(0.2))
                        .frame(width: 24, height: 24)
                    
                    if isCustomAsset {
                        // Custom image asset (OpenAI logo)
                        Image(currentInfo.icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 14, height: 14)
                            .foregroundColor(currentInfo.color)
                    } else {
                        // SF Symbol
                        Image(systemName: currentInfo.icon)
                            .font(.system(size: 10))
                            .foregroundColor(currentInfo.color)
                    }
                }
                
                if !isCompact {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(currentInfo.name)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text(appState.selectedTTSEngine.displayName)
                            .font(.system(size: 9))
                            .foregroundColor(Color(white: 0.5))
                    }
                }
                
                Image(systemName: "chevron.up")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(white: 0.3))
            }
            .padding(.leading, 6)
            .padding(.trailing, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(showMenu || isHovered ? 0.08 : 0.04))
            )
            .overlay(
                 RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(currentInfo.color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .popover(isPresented: $showMenu) {
            UnifiedVoiceMenu()
                .environmentObject(appState)
        }
        .help("Select Voice & Engine")
    }
}

// MARK: - Unified Voice Menu

struct UnifiedVoiceMenu: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Voice Settings")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color.white.opacity(0.5))
                .padding(.horizontal, 16)
                .padding(.top, 16)
            
            ScrollView {
                VStack(spacing: 4) {
                    // Groq Section
                    ConfigSection(title: "Cloud (Groq)", active: appState.selectedTTSEngine == .groqAPI) {
                        ForEach(GroqVoice.allCases.prefix(4)) { voice in // Showing top 4 for brevity
                            SimpleVoiceRow(
                                name: voice.displayName,
                                desc: voice.gender,
                                isSelected: appState.selectedTTSEngine == .groqAPI && appState.selectedVoice == voice.rawValue
                            ) {
                                appState.updateTTSEngine(.groqAPI)
                                appState.updateVoice(voice)
                                // Don't dismiss to allow exploring
                            }
                        }
                    }
                    
                    Divider().background(Color.white.opacity(0.1)).padding(.vertical, 4)
                    
                    // Piper Section (only if downloaded)
                    if appState.ttsManager.isEngineReady() { // Simplified check, ideally check model manager
                        ConfigSection(title: "Local AI (Piper)", active: appState.selectedTTSEngine == .piper) {
                            ForEach(PiperVoice.allCases) { voice in
                                SimpleVoiceRow(
                                    name: voice.displayName,
                                    desc: "Fast & Offline",
                                    isSelected: appState.selectedTTSEngine == .piper && appState.selectedPiperVoice == voice
                                ) {
                                    appState.updateTTSEngine(.piper)
                                    appState.updatePiperVoice(voice)
                                }
                            }
                        }
                        
                        Divider().background(Color.white.opacity(0.1)).padding(.vertical, 4)
                    }
                    
                    // Native Section
                    ConfigSection(title: "macOS System", active: appState.selectedTTSEngine == .macOSNative) {
                        ForEach(NativeVoice.allCases) { voice in
                            SimpleVoiceRow(
                                name: voice.displayName,
                                desc: "Offline",
                                isSelected: appState.selectedTTSEngine == .macOSNative && appState.selectedNativeVoice == voice
                            ) {
                                appState.updateTTSEngine(.macOSNative)
                                appState.updateNativeVoice(voice)
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 16)
            }
            .frame(height: 300)
            
            // Footer to full settings
            Button(action: {
                dismiss()
                appState.showPreferences = true
            }) {
                HStack {
                    Image(systemName: "gearshape.fill")
                    Text("More Settings...")
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color(red: 0.36, green: 0.67, blue: 1.0))
                .frame(maxWidth: .infinity)
                .padding(10)
                .background(Color.white.opacity(0.05))
            }
            .buttonStyle(.plain)
        }
        .frame(width: 260)
        .background(Color(red: 0.12, green: 0.14, blue: 0.19))
    }
}

struct ConfigSection<Content: View>: View {
    let title: String
    let active: Bool
    let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(active ? .white : Color.white.opacity(0.6))
                
                Spacer()
                
                if active {
                    Circle().fill(Color.green).frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            
            content()
        }
    }
}

struct SimpleVoiceRow: View {
    let name: String
    let desc: String
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading) {
                    Text(name).font(.system(size: 12, weight: .medium)).foregroundColor(.white)
                    Text(desc).font(.system(size: 10)).foregroundColor(.white.opacity(0.5))
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark").font(.system(size: 10)).foregroundColor(.blue)
                }
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 6).fill(isSelected ? Color.blue.opacity(0.2) : (isHovered ? Color.white.opacity(0.05) : Color.clear)))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
// MARK: - Speed Picker Popover

struct SpeedPickerPopover: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 4) {
            ForEach(AppState.speedPresets, id: \.self) { speed in
                Button(action: {
                    appState.playbackSpeed = speed
                    appState.saveState()
                    dismiss()
                }) {
                    HStack {
                        Text("\(speed, specifier: "%.1f")×")
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundColor(appState.playbackSpeed == speed ? .white : Color.white.opacity(0.7))
                        
                        Spacer()
                        
                        if appState.playbackSpeed == speed {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12))
                                .foregroundColor(Color(red: 0.36, green: 0.67, blue: 1.0))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(appState.playbackSpeed == speed ? Color(red: 0.36, green: 0.67, blue: 1.0).opacity(0.15) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .frame(width: 120)
        .background(Color(red: 0.12, green: 0.14, blue: 0.19))
    }
}
