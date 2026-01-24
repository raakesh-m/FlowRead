// TTSPreferencesView.swift
// FlowRead - TTS Engine selection and configuration view

import SwiftUI

struct TTSEnginePreferences: View {
    @EnvironmentObject var appState: AppState
    
    // Observe the download manager directly for real-time updates
    @ObservedObject var downloadManager: ModelDownloadManager
    
    // Colors
    let textWhite = Color.white
    let textGray = Color(white: 0.8)
    let vibrantBlue = Color(red: 0.36, green: 0.67, blue: 1.0)
    let vibrantPurple = Color(red: 0.69, green: 0.46, blue: 1.0)
    let vibrantGreen = Color(red: 0.30, green: 0.78, blue: 0.47)
    let vibrantOrange = Color(red: 1.0, green: 0.62, blue: 0.04)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // TTS Enable Toggle
            PreferenceSection(title: "Text-to-Speech", icon: "waveform") {
                ToggleRow(
                    title: "Enable TTS",
                    subtitle: "Read text aloud using selected engine",
                    isOn: $appState.isTTSEnabled
                )
                .onChange(of: appState.isTTSEnabled) { _ in
                    appState.saveState()
                }
            }
            
            // Engine Selection
            PreferenceSection(title: "TTS Engine", icon: "cpu") {
                VStack(spacing: 12) {
                    // macOS Native
                    TTSEngineRow(
                        engine: .macOSNative,
                        isSelected: appState.selectedTTSEngine == .macOSNative,
                        status: .ready,
                        action: { appState.updateTTSEngine(.macOSNative) }
                    )
                    
                    // Groq API
                    TTSEngineRow(
                        engine: .groqAPI,
                        isSelected: appState.selectedTTSEngine == .groqAPI,
                        status: .ready,
                        statusNote: "Requires API Key",
                        action: { appState.updateTTSEngine(.groqAPI) }
                    )
                    
                    // Kokoro-82M
                    TTSEngineRow(
                        engine: .kokoro,
                        isSelected: appState.selectedTTSEngine == .kokoro,
                        status: downloadStatusForKokoro,
                        action: {
                            if downloadManager.kokoroStatus.isDownloaded {
                                appState.updateTTSEngine(.kokoro)
                            }
                        },
                        downloadAction: {
                            Task {
                                await downloadManager.downloadKokoroModel()
                            }
                        },
                        cancelAction: {
                            downloadManager.cancelKokoroDownload()
                        },
                        deleteAction: {
                            downloadManager.deleteKokoroModel()
                            if appState.selectedTTSEngine == .kokoro {
                                appState.updateTTSEngine(.macOSNative)
                            }
                        }
                    )
                    
                    // Piper TTS
                    TTSEngineRow(
                        engine: .piper,
                        isSelected: appState.selectedTTSEngine == .piper,
                        status: downloadStatusForPiper,
                        action: {
                            if downloadManager.piperStatus.isDownloaded {
                                appState.updateTTSEngine(.piper)
                            }
                        },
                        downloadAction: {
                            Task {
                                await downloadManager.downloadPiperPack()
                            }
                        },
                        cancelAction: {
                            downloadManager.cancelPiperPackDownload()
                        },
                        deleteAction: {
                            downloadManager.deletePiperPack()
                            if appState.selectedTTSEngine == .piper {
                                appState.updateTTSEngine(.macOSNative)
                            }
                        }
                    )
                }
            }
            
            // Voice Selection (based on selected engine)
            voiceSelectionSection
        }
        .onAppear {
            downloadManager.checkExistingModels()
        }
    }
    
    // MARK: - Computed Status
    
    private var downloadStatusForKokoro: TTSEngineStatus {
        switch downloadManager.kokoroStatus {
        case .notDownloaded:
            return .needsDownload
        case .downloading(let progress, let downloaded, let total):
            return .downloading(progress: progress, downloaded: downloaded, total: total)
        case .downloaded:
            return .ready
        case .deleting:
            return .deleting
        case .failed(let error):
            return .error(message: error)
        }
    }
    
    private var downloadStatusForPiper: TTSEngineStatus {
        switch downloadManager.piperStatus {
        case .notDownloaded:
            return .needsDownload
        case .downloading(let progress, let downloaded, let total):
            return .downloading(progress: progress, downloaded: downloaded, total: total)
        case .downloaded:
            return .ready
        case .deleting:
            return .deleting
        case .failed(let error):
            return .error(message: error)
        }
    }
    
    // MARK: - Voice Selection Section
    
    @ViewBuilder
    private var voiceSelectionSection: some View {
        switch appState.selectedTTSEngine {
        case .macOSNative:
            NativeVoiceSelection()
        case .groqAPI:
            GroqVoiceSelection()
        case .kokoro:
            if downloadManager.kokoroStatus.isDownloaded {
                KokoroVoiceSelection()
            }
        case .piper:
            if downloadManager.piperStatus.isDownloaded {
                PiperVoiceSelection()
            }
        }
    }
}

// MARK: - TTS Engine Status

enum TTSEngineStatus {
    case ready
    case needsDownload
    case downloading(progress: Double, downloaded: Int64, total: Int64)
    case deleting
    case error(message: String)
}

// MARK: - TTS Engine Row

struct TTSEngineRow: View {
    let engine: TTSEngine
    let isSelected: Bool
    let status: TTSEngineStatus
    var statusNote: String? = nil
    let action: () -> Void
    var downloadAction: (() -> Void)? = nil
    var cancelAction: (() -> Void)? = nil
    var deleteAction: (() -> Void)? = nil
    
    @State private var isHovered = false
    
    let vibrantBlue = Color(red: 0.36, green: 0.67, blue: 1.0)
    let vibrantGreen = Color(red: 0.30, green: 0.78, blue: 0.47)
    let vibrantOrange = Color(red: 1.0, green: 0.62, blue: 0.04)
    let textGray = Color(white: 0.8)
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                // Selection indicator
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? vibrantBlue : Color.white.opacity(0.3), lineWidth: 2)
                        .frame(width: 20, height: 20)
                    
                    if isSelected {
                        Circle()
                            .fill(vibrantBlue)
                            .frame(width: 12, height: 12)
                    }
                }
                .opacity(canSelect ? 1 : 0.5)
                
                // Engine icon
                Image(systemName: engine.icon)
                    .font(.system(size: 18))
                    .foregroundColor(isSelected ? vibrantBlue : Color(white: 0.6))
                    .frame(width: 24)
                
                // Engine info
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(engine.displayName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        
                        // Quality badge
                        Text(engine.qualityLabel)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(qualityColor.opacity(0.8))
                            .cornerRadius(4)
                    }
                    
                    Text(engine.description)
                        .font(.system(size: 11))
                        .foregroundColor(Color(white: 0.5))
                }
                
                Spacer()
                
                // Status / Action area
                statusView
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? vibrantBlue.opacity(0.15) : Color.white.opacity(isHovered ? 0.08 : 0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isSelected ? vibrantBlue.opacity(0.4) : Color.clear, lineWidth: 1)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                if canSelect {
                    action()
                }
            }
            .onHover { isHovered = $0 }
            
            // Download progress bar (shown when downloading)
            if case .downloading(let progress, let downloaded, let total) = status {
                VStack(spacing: 4) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.white.opacity(0.1))
                            
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [vibrantBlue, vibrantGreen],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * progress)
                        }
                    }
                    .frame(height: 6)
                    .cornerRadius(3)
                    
                    HStack {
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color(white: 0.6))
                        
                        Spacer()
                        
                        Text("\(ModelDownloadManager.formatBytes(downloaded)) / \(ModelDownloadManager.formatBytes(total))")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color(white: 0.6))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
        }
    }
    
    private var canSelect: Bool {
        switch status {
        case .ready:
            return true
        case .needsDownload, .downloading, .deleting, .error:
            return false
        }
    }
    
    private var qualityColor: Color {
        switch engine.qualityRating {
        case 5: return vibrantGreen
        case 4: return vibrantBlue
        default: return vibrantOrange
        }
    }
    
    @ViewBuilder
    private var statusView: some View {
        switch status {
        case .ready:
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(vibrantGreen)
                    .font(.system(size: 18))
            } else if statusNote != nil {
                Text(statusNote!)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color(white: 0.5))
            }
            
            if let deleteAction = deleteAction, engine.requiresDownload {
                Button(action: deleteAction) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("Delete downloaded model")
            }
            
        case .needsDownload:
            if let downloadAction = downloadAction {
                Button(action: downloadAction) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 12))
                        Text("Download \(engine.downloadSizeFormatted)")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(vibrantBlue)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            
        case .downloading(let progress, let downloaded, let total):
            VStack(alignment: .trailing, spacing: 4) {
                // Progress Bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .foregroundColor(Color.gray.opacity(0.3))
                            .cornerRadius(2)
                        
                        Rectangle()
                            .foregroundColor(vibrantBlue)
                            .frame(width: CGFloat(max(0, min(1, progress))) * geometry.size.width)
                            .cornerRadius(2)
                    }
                }
                .frame(width: 80, height: 4)
                
                HStack(spacing: 4) {
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(textGray)
                    
                    if let cancelAction = cancelAction {
                        Button(action: cancelAction) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.red.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
        case .deleting:
            HStack(spacing: 6) {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 16, height: 16)
                Text("Deleting...")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(white: 0.6))
            }
            
        case .error(let message):
            VStack(alignment: .trailing, spacing: 2) {
                Text("Error")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.red)
                Text(message)
                    .font(.system(size: 9))
                    .foregroundColor(.red.opacity(0.8))
                    .lineLimit(1)
            }
            
            if let downloadAction = downloadAction {
                Button(action: downloadAction) {
                    Text("Retry")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(vibrantOrange)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Native Voice Selection

struct NativeVoiceSelection: View {
    @EnvironmentObject var appState: AppState
    
    let vibrantBlue = Color(red: 0.36, green: 0.67, blue: 1.0)
    
    var body: some View {
        PreferenceSection(title: "macOS Voice", icon: "speaker.wave.2") {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(NativeVoice.allCases) { voice in
                    VoiceOptionButton(
                        name: voice.displayName,
                        description: voice.description,
                        isSelected: appState.selectedNativeVoice == voice,
                        action: { appState.updateNativeVoice(voice) }
                    )
                }
            }
            
            // Note about available voices
            Text("Only Samantha and Daniel are currently supported for best quality.")
                .font(.system(size: 10))
                .foregroundColor(Color(white: 0.5))
                .padding(.top, 4)
        }
    }
}

// MARK: - Groq Voice Selection

struct GroqVoiceSelection: View {
    @EnvironmentObject var appState: AppState
    
    private var currentVoice: GroqVoice {
        GroqVoice(rawValue: appState.selectedVoice) ?? .hannah
    }
    
    var body: some View {
        PreferenceSection(title: "Groq Voice", icon: "cloud") {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(GroqVoice.allCases) { voice in
                    VoiceOptionButton(
                        name: voice.displayName,
                        description: voice.description,
                        isSelected: currentVoice == voice,
                        action: { appState.updateVoice(voice) }
                    )
                }
            }
        }
    }
}

// MARK: - Kokoro Voice Selection

struct KokoroVoiceSelection: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        PreferenceSection(title: "Kokoro Voice", icon: "waveform.circle") {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(KokoroVoice.allCases) { voice in
                    VoiceOptionButton(
                        name: voice.displayName,
                        description: voice.description,
                        isSelected: appState.selectedKokoroVoice == voice,
                        action: { appState.updateKokoroVoice(voice) }
                    )
                }
            }
        }
    }
}

// MARK: - Piper Voice Selection

struct PiperVoiceSelection: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        PreferenceSection(title: "Piper Voice", icon: "speaker.wave.3") {
            HStack(spacing: 8) {
                ForEach(PiperVoice.allCases) { voice in
                    VoiceOptionButton(
                        name: voice.displayName,
                        description: voice.description,
                        isSelected: appState.selectedPiperVoice == voice,
                        action: { appState.updatePiperVoice(voice) }
                    )
                }
            }
        }
    }
}

// MARK: - Voice Option Button

struct VoiceOptionButton: View {
    let name: String
    let description: String
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    let vibrantBlue = Color(red: 0.36, green: 0.67, blue: 1.0)
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(name)
                    .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? .white : Color(white: 0.8))
                
                Text(description)
                    .font(.system(size: 9))
                    .foregroundColor(isSelected ? Color(white: 0.9) : Color(white: 0.5))
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? vibrantBlue : Color.white.opacity(isHovered ? 0.1 : 0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? Color.clear : Color.white.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
