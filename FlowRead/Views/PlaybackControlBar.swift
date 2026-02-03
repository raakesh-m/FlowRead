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
        .focusable(false)
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
        .focusable(false)
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
                    Text(String(format: "%.2fx", appState.playbackSpeed))
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
        .focusable(false)
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
        .focusable(false)
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
    
    // Check availability
    private var isGroqAvailable: Bool {
        appState.ttsManager.isGroqConfigured
    }
    
    private var isOpenAIAvailable: Bool {
        appState.ttsManager.isOpenAIConfigured
    }
    
    private var isPiperAvailable: Bool {
        appState.modelDownloadManager.piperStatus.isDownloaded
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color(red: 0.36, green: 0.67, blue: 1.0))
                Text("Voice Settings")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            ScrollView {
                VStack(spacing: 8) {
                    // macOS Native - Always available
                    VoiceSection(
                        icon: "laptopcomputer",
                        title: "macOS System",
                        subtitle: "Built-in voices",
                        color: .blue,
                        isActive: appState.selectedTTSEngine == .macOSNative,
                        isAvailable: true
                    ) {
                        ForEach(NativeVoice.allCases) { voice in
                            VoiceOptionRow(
                                icon: "person.wave.2.fill",
                                name: voice.displayName,
                                desc: "Offline • Fast",
                                isSelected: appState.selectedTTSEngine == .macOSNative && appState.selectedNativeVoice == voice,
                                color: .blue
                            ) {
                                appState.updateTTSEngine(.macOSNative)
                                appState.updateNativeVoice(voice)
                            }
                        }
                    }
                    
                    // Piper - Available if downloaded
                    VoiceSection(
                        icon: "waveform.path.ecg",
                        title: "Piper AI",
                        subtitle: isPiperAvailable ? "Neural voices" : "Not downloaded",
                        color: .green,
                        isActive: appState.selectedTTSEngine == .piper,
                        isAvailable: isPiperAvailable,
                        configureAction: {
                            dismiss()
                            appState.showPreferences = true
                        }
                    ) {
                        if isPiperAvailable {
                            ForEach(PiperVoice.allCases) { voice in
                                VoiceOptionRow(
                                    icon: "brain.head.profile",
                                    name: voice.displayName,
                                    desc: "Offline • AI Voice",
                                    isSelected: appState.selectedTTSEngine == .piper && appState.selectedPiperVoice == voice,
                                    color: .green
                                ) {
                                    appState.updateTTSEngine(.piper)
                                    appState.updatePiperVoice(voice)
                                }
                            }
                        } else {
                            EmptyView()
                        }
                    }
                    
                    // Groq - Available if API key set
                    VoiceSection(
                        icon: "bolt.fill",
                        title: "Groq Cloud",
                        subtitle: isGroqAvailable ? "Fast cloud TTS" : "API key required",
                        color: Color(red: 0.69, green: 0.46, blue: 1.0),
                        isActive: appState.selectedTTSEngine == .groqAPI,
                        isAvailable: isGroqAvailable,
                        configureAction: {
                            dismiss()
                            appState.showPreferences = true
                        }
                    ) {
                        if isGroqAvailable {
                            ForEach(GroqVoice.allCases.prefix(4)) { voice in
                                VoiceOptionRow(
                                    icon: "cloud.fill",
                                    name: voice.displayName,
                                    desc: voice.gender,
                                    isSelected: appState.selectedTTSEngine == .groqAPI && appState.selectedVoice == voice.rawValue,
                                    color: Color(red: 0.69, green: 0.46, blue: 1.0)
                                ) {
                                    appState.updateTTSEngine(.groqAPI)
                                    appState.updateVoice(voice)
                                }
                            }
                        } else {
                            EmptyView()
                        }
                    }
                    
                    // OpenAI - Available if API key set
                    VoiceSection(
                        icon: "sparkles",
                        title: "OpenAI",
                        subtitle: isOpenAIAvailable ? "Premium voices" : "API key required",
                        color: Color(red: 0.4, green: 0.8, blue: 0.6),
                        isActive: appState.selectedTTSEngine == .openAI,
                        isAvailable: isOpenAIAvailable,
                        configureAction: {
                            dismiss()
                            appState.showPreferences = true
                        }
                    ) {
                        if isOpenAIAvailable {
                            ForEach(["alloy", "echo", "fable", "onyx"], id: \.self) { voice in
                                VoiceOptionRow(
                                    icon: "waveform",
                                    name: voice.capitalized,
                                    desc: "High Quality",
                                    isSelected: appState.selectedTTSEngine == .openAI,
                                    color: Color(red: 0.4, green: 0.8, blue: 0.6)
                                ) {
                                    appState.updateTTSEngine(.openAI)
                                }
                            }
                        } else {
                            EmptyView()
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 12)
            }
            .frame(height: 340)
            
            // Footer
            Button(action: {
                dismiss()
                appState.showPreferences = true
            }) {
                HStack {
                    Image(systemName: "gearshape.fill")
                    Text("All Settings...")
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color(red: 0.36, green: 0.67, blue: 1.0))
                .frame(maxWidth: .infinity)
                .padding(10)
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .focusable(false)
            .padding(.horizontal, 8)
            .padding(.bottom, 12)
        }
        .frame(width: 280)
        .background(Color(red: 0.10, green: 0.12, blue: 0.16))
    }
}

// MARK: - Voice Section

struct VoiceSection<Content: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let isActive: Bool
    let isAvailable: Bool
    var configureAction: (() -> Void)? = nil
    let content: () -> Content
    
    init(icon: String, title: String, subtitle: String, color: Color, isActive: Bool, isAvailable: Bool, configureAction: (() -> Void)? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.color = color
        self.isActive = isActive
        self.isAvailable = isAvailable
        self.configureAction = configureAction
        self.content = content
    }
    
    @State private var isExpanded: Bool = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header
            Button(action: { 
                if isAvailable {
                    withAnimation(.spring(response: 0.3)) {
                        isExpanded.toggle()
                    }
                } else {
                    configureAction?()
                }
            }) {
                HStack(spacing: 10) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(color.opacity(isAvailable ? 0.2 : 0.1))
                            .frame(width: 28, height: 28)
                        
                        Image(systemName: icon)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(isAvailable ? color : color.opacity(0.5))
                    }
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(isAvailable ? .white : .white.opacity(0.5))
                        
                        Text(subtitle)
                            .font(.system(size: 10))
                            .foregroundColor(isAvailable ? color.opacity(0.8) : .orange.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    if !isAvailable {
                        // Configure button
                        Text("Configure")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.15))
                            .cornerRadius(4)
                    } else {
                        // Active indicator + expand
                        HStack(spacing: 6) {
                            if isActive {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 6, height: 6)
                            }
                            
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isActive ? color.opacity(0.1) : Color.white.opacity(0.03))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isActive ? color.opacity(0.3) : Color.clear, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .focusable(false)

            // Content (voices)
            if isAvailable && isExpanded {
                content()
                    .padding(.leading, 38)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Voice Option Row

struct VoiceOptionRow: View {
    let icon: String
    let name: String
    let desc: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(isSelected ? color : .white.opacity(0.5))
                    .frame(width: 16)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(name)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(isSelected ? .white : .white.opacity(0.8))
                    
                    Text(desc)
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.4))
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(color)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? color.opacity(0.15) : (isHovered ? Color.white.opacity(0.05) : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .focusable(false)
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
                        Text(String(format: "%.2f×", speed))
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
                .focusable(false)
            }
        }
        .padding(8)
        .frame(width: 120)
        .background(Color(red: 0.12, green: 0.14, blue: 0.19))
    }
}
