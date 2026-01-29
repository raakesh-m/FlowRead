// TTSPreferencesView.swift
// FlowRead - Online and Offline TTS Settings Components

import SwiftUI

// MARK: - Online Settings View

struct OnlineSettingsView: View {
    @EnvironmentObject var appState: AppState
    
    // Explicit colors
    let textWhite = Color.white
    let textGray = Color(white: 0.8)
    let vibrantBlue = Color(red: 0.36, green: 0.67, blue: 1.0)
    let vibrantPurple = Color(red: 0.69, green: 0.46, blue: 1.0)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            
            // 1. Enable/Disable Toggle
            // (If we want to allow disabling 'Online' specifically, or just use the global TTS toggle?
            // The prompt implies splitting into Online/Offline capabilities.
            // Let's assume selecting the tab implies intent, but we still need that global TTS toggle somewhere.
            // Maybe global toggle should be in General or distinct.
            // For now, let's put the Global TTS toggle in General instead, and here focus on configuration.)
            
            // 2. Provider Selection (Currently only Groq)
            PreferenceSection(title: "Provider", icon: "cloud.fill") {
                HStack {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [vibrantBlue, vibrantPurple], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Groq API")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(textWhite)
                        Text("Ultra-fast cloud inference")
                            .font(.system(size: 12))
                            .foregroundColor(textGray)
                    }
                    
                    Spacer()
                    
                    if appState.selectedTTSEngine == .groqAPI {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(vibrantBlue)
                            .font(.system(size: 20))
                    } else {
                        Button("Activate") {
                            appState.updateTTSEngine(.groqAPI)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(vibrantBlue.opacity(0.2))
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(vibrantBlue, lineWidth: 1))
                    }
                }
                .padding(12)
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
            }
            
            // 3. API Keys Management
            APIKeyManagementView()
            
            // 4. Voice Selection
            if appState.selectedTTSEngine == .groqAPI {
                GroqVoiceSelection()
            } else {
                Text("Activate Groq API to configure voices.")
                    .font(.system(size: 13))
                    .foregroundColor(Color.white.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
    }
}

// MARK: - Offline Settings View

struct OfflineSettingsView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var downloadManager: ModelDownloadManager
    
    let vibrantBlue = Color(red: 0.36, green: 0.67, blue: 1.0)
    let vibrantGreen = Color(red: 0.30, green: 0.78, blue: 0.47)
     let vibrantOrange = Color(red: 1.0, green: 0.62, blue: 0.04)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            
            // 1. Engine Selection
            PreferenceSection(title: "Offline Engine", icon: "cpu") {
                VStack(spacing: 12) {
                    // macOS Native
                    TTSEngineRow(
                        engine: .macOSNative,
                        isSelected: appState.selectedTTSEngine == .macOSNative,
                        status: .ready,
                        action: { appState.updateTTSEngine(.macOSNative) }
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
            
            // 2. Voice Selection
            if appState.selectedTTSEngine == .macOSNative {
                NativeVoiceSelection()
            } else if appState.selectedTTSEngine == .piper && downloadManager.piperStatus.isDownloaded {
                PiperVoiceSelection()
            }
        }
        .onAppear {
            downloadManager.checkExistingModels()
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
}

// MARK: - API Key Management Component

struct APIKeyManagementView: View {
    @EnvironmentObject var appState: AppState
    @State private var apiKeys: [String] = [""]
    @State private var showKeys: Bool = false
    @State private var statusMessage: String = ""
    @State private var isSuccess: Bool = false
    
    let vibrantBlue = Color(red: 0.36, green: 0.67, blue: 1.0)
    let vibrantPurple = Color(red: 0.69, green: 0.46, blue: 1.0)
    
    var body: some View {
        PreferenceSection(title: "API Keys", icon: "key.fill") {
            VStack(alignment: .leading, spacing: 12) {
                // Info text
                Text("Add multiple keys for load balancing. Free tier: ~30 req/min. Keys rotate automatically.")
                    .font(.system(size: 11))
                    .foregroundColor(Color.white.opacity(0.6))
                    .padding(.bottom, 4)
                
                ForEach(Array(apiKeys.enumerated()), id: \.offset) { index, _ in
                    HStack(spacing: 12) {
                        // Badge
                        ZStack {
                            Circle()
                                .fill(apiKeys[index].isEmpty ? Color.white.opacity(0.05) : vibrantBlue)
                                .frame(width: 24, height: 24)
                            
                            Text("\(index + 1)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(apiKeys[index].isEmpty ? Color(white: 0.5) : .white)
                        }
                        
                        // Input
                        Group {
                            if showKeys {
                                TextField("gsk_...", text: $apiKeys[index])
                            } else {
                                SecureField("gsk_...", text: $apiKeys[index])
                            }
                        }
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, design: .monospaced))
                        .padding(10)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(
                                    apiKeys[index].isEmpty ? Color.white.opacity(0.1) : vibrantBlue.opacity(0.3),
                                    lineWidth: 1
                                )
                        )
                        
                        // Remove button
                        if apiKeys.count > 1 {
                            Button(action: { removeKey(at: index) }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                // Add button
                Button(action: addKeySlot) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add API Key")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(vibrantBlue)
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(vibrantBlue.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                // Action row
                HStack {
                    Button(action: { showKeys.toggle() }) {
                        Label(showKeys ? "Hide" : "Show", systemImage: showKeys ? "eye.slash" : "eye")
                            .font(.system(size: 12))
                            .foregroundColor(Color.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    Button(action: saveAPIKeys) {
                        Label("Save Keys", systemImage: "checkmark.circle")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(vibrantBlue)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
                
                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.system(size: 11))
                        .foregroundColor(isSuccess ? .green : .red)
                }
            }
        }
        .onAppear { loadAPIKeys() }
    }
    
    private func addKeySlot() {
        withAnimation { apiKeys.append("") }
    }
    
    private func removeKey(at index: Int) {
        withAnimation {
            if apiKeys.count > 1 { apiKeys.remove(at: index) }
        }
    }
    
    private func loadAPIKeys() {
        let configPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".flowread/api_keys.json")
        
        if FileManager.default.fileExists(atPath: configPath.path) {
            do {
                let data = try Data(contentsOf: configPath)
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let keys = json["groq_api_keys"] as? [String] {
                    apiKeys = keys.isEmpty ? [""] : keys
                }
            } catch {
                print("Failed to load keys: \(error)")
            }
        }
    }
    
    private func saveAPIKeys() {
        let configDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".flowread")
        do {
            try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
            let validKeys = apiKeys.filter { !$0.isEmpty }
            let json = ["groq_api_keys": validKeys]
            let data = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
            try data.write(to: configDir.appendingPathComponent("api_keys.json"))
            
            appState.reloadKeys()
            statusMessage = "Keys saved successfully!"
            isSuccess = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                statusMessage = ""
            }
        } catch {
            statusMessage = "Failed to save: \(error.localizedDescription)"
            isSuccess = false
        }
    }
}

// MARK: - Voice Selection Wrappers (Reused from previous, cleaned up)

struct GroqVoiceSelection: View {
    @EnvironmentObject var appState: AppState
    
    // Group voices by gender
    private var femaleVoices: [GroqVoice] { GroqVoice.allCases.filter { $0.gender == "Female" } }
    private var maleVoices: [GroqVoice] { GroqVoice.allCases.filter { $0.gender == "Male" } }
    
    var body: some View {
        VStack(spacing: 16) {
            PreferenceSection(title: "Female Voices", icon: "person.fill") {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(femaleVoices) { voice in
                        VoiceOptionButton(
                            name: voice.displayName,
                            description: voice.description,
                            isSelected: appState.selectedVoice == voice.rawValue,
                            action: { appState.updateVoice(voice) }
                        )
                    }
                }
            }
            
            PreferenceSection(title: "Male Voices", icon: "person.fill") {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(maleVoices) { voice in
                        VoiceOptionButton(
                            name: voice.displayName,
                            description: voice.description,
                            isSelected: appState.selectedVoice == voice.rawValue,
                            action: { appState.updateVoice(voice) }
                        )
                    }
                }
            }
        }
    }
}

struct NativeVoiceSelection: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        PreferenceSection(title: "macOS Voice", icon: "speaker.wave.2") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(NativeVoice.allCases) { voice in
                    VoiceOptionButton(
                        name: voice.displayName,
                        description: voice.description,
                        isSelected: appState.selectedNativeVoice == voice,
                        action: { appState.updateNativeVoice(voice) }
                    )
                }
            }
             Text("Only Samantha and Daniel are currently supported for best quality.")
                .font(.system(size: 10))
                .foregroundColor(Color(white: 0.5))
        }
    }
}

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

// MARK: - Shared Components

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
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                // Radio Button
                ZStack {
                    Circle().strokeBorder(isSelected ? vibrantBlue : Color.white.opacity(0.3), lineWidth: 2).frame(width: 20, height: 20)
                    if isSelected { Circle().fill(vibrantBlue).frame(width: 12, height: 12) }
                }
                .opacity(canSelect ? 1 : 0.5)
                
                // Content
                Image(systemName: engine.icon).font(.system(size: 18)).foregroundColor(isSelected ? vibrantBlue : Color(white: 0.6)).frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(engine.displayName).font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                        Text(engine.qualityLabel).font(.system(size: 9, weight: .bold)).foregroundColor(.white).padding(.horizontal, 6).padding(.vertical, 2).background(qualityColor.opacity(0.8)).cornerRadius(4)
                    }
                    Text(engine.description).font(.system(size: 11)).foregroundColor(Color(white: 0.5))
                }
                
                Spacer()
                statusView
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(isSelected ? vibrantBlue.opacity(0.15) : Color.white.opacity(isHovered ? 0.08 : 0.04)))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(isSelected ? vibrantBlue.opacity(0.4) : Color.clear, lineWidth: 1))
            .onTapGesture { if canSelect { action() } }
            .onHover { isHovered = $0 }
            
            // Download Progress
            if case .downloading(let progress, let downloaded, let total) = status {
                VStack(spacing: 4) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle().fill(Color.white.opacity(0.1))
                            Rectangle().fill(LinearGradient(colors: [vibrantBlue, vibrantGreen], startPoint: .leading, endPoint: .trailing)).frame(width: geo.size.width * progress)
                        }
                    }
                    .frame(height: 6).cornerRadius(3)
                    
                    HStack {
                        Text("\(Int(progress * 100))%").font(.system(size: 10)).foregroundColor(Color(white: 0.6))
                        Spacer()
                        Text("\(ModelDownloadManager.formatBytes(downloaded)) / \(ModelDownloadManager.formatBytes(total))").font(.system(size: 10)).foregroundColor(Color(white: 0.6))
                    }
                }
                .padding(.horizontal, 12).padding(.bottom, 8)
            }
        }
    }
    
    private var canSelect: Bool {
        if case .ready = status { return true }
        return false
    }
    
    private var qualityColor: Color {
        switch engine.qualityRating {
        case 5: return vibrantGreen
        case 4: return vibrantBlue
        default: return vibrantOrange
        }
    }
    
    @ViewBuilder private var statusView: some View {
        switch status {
        case .ready:
            if isSelected { Image(systemName: "checkmark.circle.fill").foregroundColor(vibrantGreen).font(.system(size: 18)) }
            if let deleteAction = deleteAction, engine.requiresDownload {
                Button(action: deleteAction) { Image(systemName: "trash").font(.system(size: 12)).foregroundColor(.red.opacity(0.7)) }.buttonStyle(.plain).padding(.leading, 8)
            }
        case .needsDownload:
            if let downloadAction = downloadAction {
                Button(action: downloadAction) {
                    HStack(spacing: 4) { Image(systemName: "arrow.down.circle.fill"); Text("Download \(engine.downloadSizeFormatted)") }
                        .font(.system(size: 11, weight: .medium)).foregroundColor(.white).padding(6).background(vibrantBlue).cornerRadius(6)
                }.buttonStyle(.plain)
            }
        case .downloading(_, _, _):
            if let cancelAction = cancelAction {
                Button(action: cancelAction) { Image(systemName: "xmark.circle.fill").foregroundColor(.red.opacity(0.8)) }.buttonStyle(.plain)
            }
        case .deleting:
            ProgressView().scaleEffect(0.5)
        case .error(let message):
            VStack(alignment: .trailing) { Text("Error").font(.system(size: 10, weight: .bold)).foregroundColor(.red); Text(message).font(.system(size: 9)).foregroundColor(.red.opacity(0.8)).lineLimit(1) }
            if let downloadAction = downloadAction { Button("Retry", action: downloadAction).font(.system(size: 10)).padding(4).background(vibrantOrange).cornerRadius(4).buttonStyle(.plain) }
        }
    }
}

// Helper Enums
enum TTSEngineStatus {
    case ready
    case needsDownload
    case downloading(progress: Double, downloaded: Int64, total: Int64)
    case deleting
    case error(message: String)
}

struct VoiceOptionButton: View {
    let name: String
    let description: String
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(name).font(.system(size: 12, weight: isSelected ? .bold : .medium)).foregroundColor(isSelected ? .white : Color(white: 0.8))
                Text(description).font(.system(size: 9)).foregroundColor(isSelected ? Color(white: 0.9) : Color(white: 0.5)).lineLimit(1)
            }
            .padding(.horizontal, 8).padding(.vertical, 10).frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 8).fill(isSelected ? Color(red: 0.36, green: 0.67, blue: 1.0) : Color.white.opacity(isHovered ? 0.1 : 0.05)))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(isSelected ? Color.clear : Color.white.opacity(0.15), lineWidth: 1))
        }.buttonStyle(.plain).onHover { isHovered = $0 }
    }
}
