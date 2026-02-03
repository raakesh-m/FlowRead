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
            
            // 2. Provider Selection
            PreferenceSection(title: "Provider", icon: "cloud.fill") {
                VStack(spacing: 12) {
                    // Groq API
                    Button(action: {
                        appState.updateTTSEngine(.groqAPI)
                    }) {
                        HStack(spacing: 12) {
                            // Radio Button
                            ZStack {
                                Circle()
                                    .strokeBorder(appState.selectedTTSEngine == .groqAPI ? vibrantBlue : Color.white.opacity(0.3), lineWidth: 2)
                                    .frame(width: 20, height: 20)

                                if appState.selectedTTSEngine == .groqAPI {
                                    Circle()
                                        .fill(vibrantBlue)
                                        .frame(width: 12, height: 12)
                                }
                            }

                            // Provider Icon
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
                                Text("Ultra-fast cloud inference (Free tier)")
                                    .font(.system(size: 12))
                                    .foregroundColor(textGray)
                            }

                            Spacer()
                        }
                        .padding(12)
                        .background(appState.selectedTTSEngine == .groqAPI ? vibrantBlue.opacity(0.1) : Color.white.opacity(0.05))
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(appState.selectedTTSEngine == .groqAPI ? vibrantBlue.opacity(0.3) : Color.clear, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .focusable(false)

                    // OpenAI TTS
                    Button(action: {
                        appState.updateTTSEngine(.openAI)
                    }) {
                        HStack(spacing: 12) {
                            // Radio Button
                            ZStack {
                                Circle()
                                    .strokeBorder(appState.selectedTTSEngine == .openAI ? Color(red: 0.4, green: 0.8, blue: 0.6) : Color.white.opacity(0.3), lineWidth: 2)
                                    .frame(width: 20, height: 20)

                                if appState.selectedTTSEngine == .openAI {
                                    Circle()
                                        .fill(Color(red: 0.4, green: 0.8, blue: 0.6))
                                        .frame(width: 12, height: 12)
                                }
                            }

                            // Provider Icon
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(colors: [Color(red: 0.4, green: 0.8, blue: 0.6), Color(red: 0.2, green: 0.6, blue: 0.5)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 32, height: 32)

                                Image("OpenAILogo")
                                    .resizable()
                                    .renderingMode(.template)
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 18, height: 18)
                                    .foregroundColor(.white)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("OpenAI TTS")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(textWhite)
                                Text("Premium quality ($15/1M chars)")
                                    .font(.system(size: 12))
                                    .foregroundColor(textGray)
                            }

                            Spacer()
                        }
                        .padding(12)
                        .background(appState.selectedTTSEngine == .openAI ? Color(red: 0.4, green: 0.8, blue: 0.6).opacity(0.1) : Color.white.opacity(0.05))
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(appState.selectedTTSEngine == .openAI ? Color(red: 0.4, green: 0.8, blue: 0.6).opacity(0.3) : Color.clear, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                }
            }

            // 3. API Keys Management
            if appState.selectedTTSEngine == .groqAPI {
                APIKeyManagementView()
            } else if appState.selectedTTSEngine == .openAI {
                OpenAIKeyManagementView()
            }
            
            // 4. Voice Selection
            if appState.selectedTTSEngine == .groqAPI {
                GroqVoiceSelection()
            } else if appState.selectedTTSEngine == .openAI {
                OpenAIVoiceSelection()
            } else {
                Text("Activate an online provider to configure voices.")
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
    @StateObject private var piperSetup = PiperDependencyManager.shared
    @State private var showPiperSetupSheet = false
    @State private var isSettingUpPiper = false
    @State private var setupError: String? = nil
    
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
                            // Show beautiful setup sheet instead of direct download
                            showPiperSetupSheet = true
                        },
                        cancelAction: {
                            downloadManager.cancelPiperPackDownload()
                            isSettingUpPiper = false
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
        .sheet(isPresented: $showPiperSetupSheet) {
            PiperSetupSheet(
                isPresented: $showPiperSetupSheet,
                isSettingUp: $isSettingUpPiper,
                setupError: $setupError,
                piperSetup: piperSetup,
                downloadManager: downloadManager
            )
        }
    }
    
    private var downloadStatusForPiper: TTSEngineStatus {
        if isSettingUpPiper && !downloadManager.piperStatus.isDownloading {
            // Show as downloading during dependency setup
            return .downloading(progress: 0.1, downloaded: 0, total: 1)
        }
        
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

// MARK: - Beautiful Piper Setup Sheet

struct PiperSetupSheet: View {
    @Binding var isPresented: Bool
    @Binding var isSettingUp: Bool
    @Binding var setupError: String?
    @ObservedObject var piperSetup: PiperDependencyManager
    @ObservedObject var downloadManager: ModelDownloadManager
    
    @State private var currentStep: SetupStep = .info
    
    enum SetupStep {
        case info
        case installing
        case downloading
        case complete
        case error
    }
    
    let vibrantBlue = Color(red: 0.36, green: 0.67, blue: 1.0)
    let vibrantGreen = Color(red: 0.30, green: 0.78, blue: 0.47)
    let vibrantPurple = Color(red: 0.69, green: 0.46, blue: 1.0)
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with gradient
            ZStack {
                LinearGradient(
                    colors: [vibrantBlue, vibrantPurple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                VStack(spacing: 12) {
                    Image(systemName: "cpu.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.white)
                    
                    Text("Piper TTS")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Local AI Voice • Free Forever")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(.vertical, 32)
            }
            .frame(height: 180)
            
            // Content
            VStack(spacing: 20) {
                switch currentStep {
                case .info:
                    infoContent
                case .installing:
                    installingContent
                case .downloading:
                    downloadingContent
                case .complete:
                    completeContent
                case .error:
                    errorContent
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(Color(white: 0.12))
        }
        .frame(width: 420)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onChange(of: downloadManager.piperStatus) { newStatus in
            if case .downloaded = newStatus {
                currentStep = .complete
                isSettingUp = false
            }
        }
    }
    
    // MARK: - Info Content (Initial State)
    private var infoContent: some View {
        VStack(spacing: 20) {
            // Benefits
            VStack(alignment: .leading, spacing: 12) {
                benefitRow(icon: "infinity", title: "Unlimited & Free", subtitle: "No API costs, no limits, ever")
                benefitRow(icon: "wifi.slash", title: "Works Offline", subtitle: "No internet needed after setup")
                benefitRow(icon: "lock.shield", title: "100% Private", subtitle: "All processing stays on your Mac")
                benefitRow(icon: "bolt.fill", title: "Fast & Lightweight", subtitle: "Optimized for instant response")
            }
            
            Divider().background(Color.white.opacity(0.1))
            
            // Storage Info
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("One-time download")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                    Text("~150 MB total • 2 voices included")
                        .font(.system(size: 11))
                        .foregroundColor(Color(white: 0.6))
                }
                
                Spacer()
                
                Image(systemName: "externaldrive.fill")
                    .font(.system(size: 24))
                    .foregroundColor(vibrantBlue)
            }
            .padding(12)
            .background(Color.white.opacity(0.05))
            .cornerRadius(10)
            
            // Buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.plain)
                .focusable(false)
                .foregroundColor(Color(white: 0.7))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.08))
                .cornerRadius(10)
                
                Button(action: startSetup) {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                        Text("Install Piper")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(LinearGradient(colors: [vibrantBlue, vibrantPurple], startPoint: .leading, endPoint: .trailing))
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .focusable(false)
            }
        }
    }
    
    // MARK: - Installing Content
    private var installingContent: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .padding()
            
            // Show different text based on current status
            if case .installingPython = piperSetup.status {
                Text("Installing Python...")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("Please complete the Python installer\n if a window appears.")
                    .font(.system(size: 13))
                    .foregroundColor(Color(white: 0.6))
                    .multilineTextAlignment(.center)
            } else {
                Text("Setting up Piper TTS...")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("Installing required components.\nThis only happens once.")
                    .font(.system(size: 13))
                    .foregroundColor(Color(white: 0.6))
                    .multilineTextAlignment(.center)
            }
            
            // Log view
            if !piperSetup.logs.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(piperSetup.logs.suffix(5), id: \.self) { log in
                            Text(log)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(Color(white: 0.5))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 60)
                .padding(8)
                .background(Color.black.opacity(0.3))
                .cornerRadius(8)
            }
        }
    }
    
    // MARK: - Downloading Content
    private var downloadingContent: some View {
        VStack(spacing: 20) {
            if case .downloading(let progress, let downloaded, let total) = downloadManager.piperStatus {
                VStack(spacing: 12) {
                    // Progress circle
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.1), lineWidth: 8)
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(LinearGradient(colors: [vibrantBlue, vibrantGreen], startPoint: .topLeading, endPoint: .bottomTrailing), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .frame(width: 100, height: 100)
                    
                    Text("Downloading voice models...")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("\(ModelDownloadManager.formatBytes(downloaded)) / \(ModelDownloadManager.formatBytes(total))")
                        .font(.system(size: 13))
                        .foregroundColor(Color(white: 0.6))
                }
            } else {
                ProgressView()
                Text("Preparing download...")
                    .foregroundColor(Color(white: 0.6))
            }
            
            Button("Cancel") {
                downloadManager.cancelPiperPackDownload()
                isSettingUp = false
                isPresented = false
            }
            .buttonStyle(.plain)
            .focusable(false)
            .foregroundColor(.red.opacity(0.8))
            .padding(.top, 8)
        }
    }
    
    // MARK: - Complete Content
    private var completeContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(vibrantGreen)
            
            Text("All Set!")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
            
            Text("Piper TTS is ready to use.\nEnjoy unlimited free text-to-speech!")
                .font(.system(size: 14))
                .foregroundColor(Color(white: 0.7))
                .multilineTextAlignment(.center)
            
            Button("Done") {
                isPresented = false
            }
            .buttonStyle(.plain)
            .focusable(false)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(vibrantGreen)
            .cornerRadius(10)
        }
    }
    
    // MARK: - Error Content
    private var errorContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("Setup Incomplete")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            if let error = setupError {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundColor(Color(white: 0.6))
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 8) {
                Text("Python 3 is required for Piper TTS.\nYou can retry to install it automatically.")
                    .font(.system(size: 12))
                    .foregroundColor(Color(white: 0.5))
                    .multilineTextAlignment(.center)
            }
            
            HStack(spacing: 12) {
                Button("Close") {
                    isPresented = false
                }
                .buttonStyle(.plain)
                .focusable(false)
                .foregroundColor(Color(white: 0.7))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.08))
                .cornerRadius(10)
                
                Button("Retry") {
                    currentStep = .info
                    setupError = nil
                }
                .buttonStyle(.plain)
                .focusable(false)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(vibrantBlue)
                .cornerRadius(10)
            }
        }
    }
    
    // MARK: - Helper Views
    private func benefitRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(vibrantBlue)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(Color(white: 0.6))
            }
            
            Spacer()
        }
    }
    
    // MARK: - Setup Flow
    private func startSetup() {
        isSettingUp = true
        currentStep = .installing
        
        Task {
            // Step 1: Check and install dependencies
            // This will automatically:
            // - Check if Python is installed
            // - Download and install Python if missing (shows macOS installer)
            // - Install piper-tts package
            let dependenciesReady = await piperSetup.ensureReady()
            
            if !dependenciesReady {
                switch piperSetup.status {
                case .pythonNotFound:
                    setupError = "Python 3 installation was cancelled or failed."
                case .failed(let error):
                    setupError = error
                default:
                    setupError = "Failed to install required components."
                }
                currentStep = .error
                isSettingUp = false
                return
            }
            
            // Step 2: Download models
            currentStep = .downloading
            await downloadManager.downloadPiperPack()
            
            // Status change will trigger completion via onChange
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
                            .focusable(false)
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
                .focusable(false)

                // Action row
                HStack {
                    Button(action: { showKeys.toggle() }) {
                        Label(showKeys ? "Hide" : "Show", systemImage: showKeys ? "eye.slash" : "eye")
                            .font(.system(size: 12))
                            .foregroundColor(Color.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .focusable(false)

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
                    .focusable(false)
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
                Button(action: deleteAction) { Image(systemName: "trash").font(.system(size: 12)).foregroundColor(.red.opacity(0.7)) }.buttonStyle(.plain).focusable(false).padding(.leading, 8)
            }
        case .needsDownload:
            if let downloadAction = downloadAction {
                Button(action: downloadAction) {
                    HStack(spacing: 4) { Image(systemName: "arrow.down.circle.fill"); Text("Download \(engine.downloadSizeFormatted)") }
                        .font(.system(size: 11, weight: .medium)).foregroundColor(.white).padding(6).background(vibrantBlue).cornerRadius(6)
                }.buttonStyle(.plain).focusable(false)
            }
        case .downloading(_, _, _):
            if let cancelAction = cancelAction {
                Button(action: cancelAction) { Image(systemName: "xmark.circle.fill").foregroundColor(.red.opacity(0.8)) }.buttonStyle(.plain).focusable(false)
            }
        case .deleting:
            ProgressView().scaleEffect(0.5)
        case .error(let message):
            VStack(alignment: .trailing) { Text("Error").font(.system(size: 10, weight: .bold)).foregroundColor(.red); Text(message).font(.system(size: 9)).foregroundColor(.red.opacity(0.8)).lineLimit(1) }
            if let downloadAction = downloadAction { Button("Retry", action: downloadAction).font(.system(size: 10)).padding(4).background(vibrantOrange).cornerRadius(4).buttonStyle(.plain).focusable(false) }
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
        }.buttonStyle(.plain).focusable(false).onHover { isHovered = $0 }
    }
}

// MARK: - OpenAI API Key Management

struct OpenAIKeyManagementView: View {
    @EnvironmentObject var appState: AppState
    @State private var apiKey: String = ""
    @State private var showKey: Bool = false
    @State private var statusMessage: String = ""
    @State private var isSuccess: Bool = false
    
    let vibrantGreen = Color(red: 0.4, green: 0.8, blue: 0.6)
    
    var body: some View {
        PreferenceSection(title: "OpenAI API Key", icon: "key.fill") {
            VStack(alignment: .leading, spacing: 12) {
                // Info text
                Text("Get your API key from platform.openai.com. Standard: $15/1M chars, HD: $30/1M chars.")
                    .font(.system(size: 11))
                    .foregroundColor(Color.white.opacity(0.6))
                    .padding(.bottom, 4)
                
                HStack(spacing: 12) {
                    // Badge
                    ZStack {
                        Circle()
                            .fill(apiKey.isEmpty ? Color.white.opacity(0.05) : vibrantGreen)
                            .frame(width: 24, height: 24)
                        
                        Image(systemName: "key.fill")
                            .font(.system(size: 11))
                            .foregroundColor(apiKey.isEmpty ? Color(white: 0.5) : .white)
                    }
                    
                    // Input
                    Group {
                        if showKey {
                            TextField("sk-...", text: $apiKey)
                        } else {
                            SecureField("sk-...", text: $apiKey)
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
                                apiKey.isEmpty ? Color.white.opacity(0.1) : vibrantGreen.opacity(0.3),
                                lineWidth: 1
                            )
                    )
                }
                
                // Action row
                HStack {
                    Button(action: { showKey.toggle() }) {
                        Label(showKey ? "Hide" : "Show", systemImage: showKey ? "eye.slash" : "eye")
                            .font(.system(size: 12))
                            .foregroundColor(Color.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .focusable(false)

                    Spacer()

                    Button(action: saveAPIKey) {
                        Label("Save Key", systemImage: "checkmark.circle")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(vibrantGreen)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                }

                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.system(size: 11))
                        .foregroundColor(isSuccess ? .green : .red)
                }
            }
        }
        .onAppear { loadAPIKey() }
    }
    
    private func loadAPIKey() {
        let configPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".flowread/api_keys.json")
        
        if FileManager.default.fileExists(atPath: configPath.path) {
            do {
                let data = try Data(contentsOf: configPath)
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let key = json["openai_api_key"] as? String {
                    apiKey = key
                }
            } catch {
                print("Failed to load OpenAI key: \(error)")
            }
        }
    }
    
    private func saveAPIKey() {
        let configDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".flowread")
        let configPath = configDir.appendingPathComponent("api_keys.json")
        
        do {
            try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
            
            // Load existing config
            var json: [String: Any] = [:]
            if FileManager.default.fileExists(atPath: configPath.path) {
                let data = try Data(contentsOf: configPath)
                json = (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
            }
            
            // Update OpenAI key
            json["openai_api_key"] = apiKey
            
            let data = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
            try data.write(to: configPath)
            
            // Reload in TTS Manager
            Task {
                await appState.ttsManager.setOpenAIAPIKey(apiKey)
            }
            
            statusMessage = "Key saved successfully!"
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

// MARK: - OpenAI Voice Selection

struct OpenAIVoiceSelection: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedVoice: OpenAIVoice = .nova
    
    let vibrantGreen = Color(red: 0.4, green: 0.8, blue: 0.6)
    
    var body: some View {
        PreferenceSection(title: "OpenAI Voice", icon: "speaker.wave.2") {
            VStack(spacing: 12) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(OpenAIVoice.allCases) { voice in
                        OpenAIVoiceButton(
                            voice: voice,
                            isSelected: selectedVoice == voice,
                            action: {
                                selectedVoice = voice
                                Task {
                                    await appState.ttsManager.setOpenAIVoice(voice)
                                }
                            }
                        )
                    }
                }
                
                Text("All voices support multiple languages and work best in English.")
                    .font(.system(size: 10))
                    .foregroundColor(Color(white: 0.5))
            }
        }
        .onAppear {
            Task {
                selectedVoice = await appState.ttsManager.getOpenAIVoice()
            }
        }
    }
}

struct OpenAIVoiceButton: View {
    let voice: OpenAIVoice
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false
    
    let vibrantGreen = Color(red: 0.4, green: 0.8, blue: 0.6)
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(voice.displayName)
                    .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? .white : Color(white: 0.8))
                
                Text(voice.description)
                    .font(.system(size: 9))
                    .foregroundColor(isSelected ? Color(white: 0.9) : Color(white: 0.5))
                    .lineLimit(1)
                
                Text(voice.gender)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(isSelected ? Color(white: 0.8) : Color(white: 0.4))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? vibrantGreen : Color.white.opacity(isHovered ? 0.1 : 0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? Color.clear : Color.white.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .focusable(false)
        .onHover { isHovered = $0 }
    }
}
