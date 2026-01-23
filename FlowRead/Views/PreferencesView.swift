// PreferencesView.swift
// FlowRead - Modern preferences/settings view

import SwiftUI

struct PreferencesView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedTab = 0
    
    // Explicit colors to ensure visibility
    let textWhite = Color.white
    let textGray = Color(white: 0.8)
    let textMuted = Color(white: 0.6)
    let vibrantBlue = Color(red: 0.36, green: 0.67, blue: 1.0)
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with gradient
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Preferences")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(textWhite)
                    
                    Text("Customize your reading experience")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(textMuted)
                }
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(white: 0.7), Color(white: 0.5)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(24)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.137, green: 0.165, blue: 0.220),
                        Color(red: 0.118, green: 0.141, blue: 0.188)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            
            // Tab picker with modern styling
            HStack(spacing: 8) {
                TabButton(title: "General", icon: "gearshape", isSelected: selectedTab == 0) {
                    withAnimation(.spring(response: 0.3)) { selectedTab = 0 }
                }
                
                TabButton(title: "API Keys", icon: "key.fill", isSelected: selectedTab == 1) {
                    withAnimation(.spring(response: 0.3)) { selectedTab = 1 }
                }
                
                TabButton(title: "Reading", icon: "text.alignleft", isSelected: selectedTab == 2) {
                    withAnimation(.spring(response: 0.3)) { selectedTab = 2 }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            
            // Tab content
            ScrollView {
                VStack(spacing: 20) {
                    switch selectedTab {
                    case 0:
                        GeneralPreferences()
                    case 1:
                        APIKeyPreferences()
                    case 2:
                        ReadingPreferences()
                    default:
                        EmptyView()
                    }
                }
                .padding(24)
            }
            
            Spacer()
        }
        .frame(width: 560, height: 520)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.098, green: 0.118, blue: 0.157),
                    Color(red: 0.078, green: 0.094, blue: 0.133)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

// MARK: - Tab Button

struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    // Explicit colors
    let vibrantBlue = Color(red: 0.36, green: 0.67, blue: 1.0)
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(isSelected ? vibrantBlue : (isHovered ? .white : Color(white: 0.7)))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? vibrantBlue.opacity(0.15) : (isHovered ? Color.white.opacity(0.05) : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isSelected ? vibrantBlue.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - General Preferences

struct GeneralPreferences: View {
    @EnvironmentObject var appState: AppState
    
    // Explicit colors
    let textWhite = Color.white
    let vibrantBlue = Color(red: 0.36, green: 0.67, blue: 1.0)
    
    private var currentVoice: GroqVoice {
        GroqVoice(rawValue: appState.selectedVoice) ?? .hannah
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            PreferenceSection(title: "Playback", icon: "play.circle") {
                VStack(alignment: .leading, spacing: 16) {
                    // Default speed
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Default Speed")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(textWhite)
                            Text("Playback rate for audio")
                                .font(.system(size: 11))
                                .foregroundColor(Color(white: 0.5))
                        }
                        
                        Spacer()
                        
                        Menu {
                            ForEach(AppState.speedPresets, id: \.self) { speed in
                                Button(action: {
                                    appState.playbackSpeed = speed
                                    appState.saveState()
                                }) {
                                    HStack {
                                        Text("\(speed, specifier: "%.1f")×")
                                        if appState.playbackSpeed == speed {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text("\(appState.playbackSpeed, specifier: "%.1f")×")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(Color(white: 0.5))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white.opacity(0.1))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(vibrantBlue.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                    }
                    
                    // Voice Selection
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Default Voice")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(textWhite)
                            Text("TTS voice for reading")
                                .font(.system(size: 11))
                                .foregroundColor(Color(white: 0.5))
                        }
                        
                        Spacer()
                        
                        Menu {
                            ForEach(GroqVoice.allCases) { voice in
                                Button(action: {
                                    appState.updateVoice(voice)
                                }) {
                                    HStack {
                                        Text("\(voice.displayName) - \(voice.description)")
                                        if currentVoice == voice {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(currentVoice.displayName)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(Color(white: 0.5))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white.opacity(0.1))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(vibrantBlue.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                    }
                    
                    // Auto-scroll toggle
                    ToggleRow(
                        title: "Auto-scroll",
                        subtitle: "Keep current sentence visible during playback",
                        isOn: $appState.autoScrollEnabled
                    )
                    .onChange(of: appState.autoScrollEnabled) { _ in
                        appState.saveState()
                    }
                }
            }
            
            PreferenceSection(title: "Startup", icon: "power") {
                VStack(alignment: .leading, spacing: 16) {
                    ToggleRow(
                        title: "Restore last PDF",
                        subtitle: "Open previous document on launch",
                        isOn: .constant(true)
                    )
                    
                    ToggleRow(
                        title: "Resume position",
                        subtitle: "Continue from where you left off",
                        isOn: .constant(true)
                    )
                }
            }
        }
    }
}

// MARK: - TTS Preferences

struct TTSPreferences: View {
    @EnvironmentObject var appState: AppState
    
    // Colors
    let textWhite = Color.white
    let textGray = Color(white: 0.8)
    let vibrantBlue = Color(red: 0.36, green: 0.67, blue: 1.0)
    let vibrantPurple = Color(red: 0.69, green: 0.46, blue: 1.0)
    
    private var currentVoice: GroqVoice {
        GroqVoice(rawValue: appState.selectedVoice) ?? .hannah
    }
    
    // Group voices by gender
    private var femaleVoices: [GroqVoice] {
        GroqVoice.allCases.filter { $0.gender == "Female" }
    }
    
    private var maleVoices: [GroqVoice] {
        GroqVoice.allCases.filter { $0.gender == "Male" }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Voice Selection - Female
            PreferenceSection(title: "Female Voices (\(femaleVoices.count))", icon: "person.fill") {
                VStack(spacing: 8) {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 8) {
                        ForEach(femaleVoices) { voice in
                            VoiceChipWithDescription(
                                voice: voice,
                                isSelected: currentVoice == voice,
                                action: { appState.updateVoice(voice) }
                            )
                        }
                    }
                }
            }
            
            // Voice Selection - Male
            PreferenceSection(title: "Male Voices (\(maleVoices.count))", icon: "person.fill") {
                VStack(spacing: 8) {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 8) {
                        ForEach(maleVoices) { voice in
                            VoiceChipWithDescription(
                                voice: voice,
                                isSelected: currentVoice == voice,
                                action: { appState.updateVoice(voice) }
                            )
                        }
                    }
                }
            }
            
            // TTS Toggle
            PreferenceSection(title: "Text-to-Speech", icon: "waveform") {
                ToggleRow(
                    title: "Enable TTS",
                    subtitle: "Use Groq API for voice synthesis",
                    isOn: $appState.isTTSEnabled
                )
                .onChange(of: appState.isTTSEnabled) { _ in
                    appState.saveState()
                }
            }
            
            // Rate Limits Info
            PreferenceSection(title: "API Limits & Tips", icon: "info.circle") {
                VStack(alignment: .leading, spacing: 12) {
                    LimitRow(label: "Max text per request", value: "200 chars")
                    LimitRow(label: "Free tier RPM", value: "~30/min/key")
                    LimitRow(label: "Pre-fetch chunks", value: "3 ahead")
                    
                    Divider()
                        .background(Color.white.opacity(0.1))
                    
                    Text("💡 Tip: Add 3-5 API keys for smooth uninterrupted playback. Keys rotate automatically.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(white: 0.6))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

// MARK: - Voice Chip With Description

struct VoiceChipWithDescription: View {
    let voice: GroqVoice
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    let vibrantBlue = Color(red: 0.36, green: 0.67, blue: 1.0)
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(voice.displayName)
                    .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? .white : Color(white: 0.8))
                
                Text(voice.description)
                    .font(.system(size: 9, weight: .regular))
                    .foregroundColor(isSelected ? Color(white: 0.9) : Color(white: 0.5))
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? vibrantBlue : Color.white.opacity(isHovered ? 0.1 : 0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isSelected ? Color.clear : Color.white.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Model Selection Row

struct ModelSelectionRow: View {
    let modelId: String
    let modelName: String
    let modelDescription: String
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    let vibrantBlue = Color(red: 0.36, green: 0.67, blue: 1.0)
    let vibrantPurple = Color(red: 0.69, green: 0.46, blue: 1.0)
    
    var body: some View {
        Button(action: action) {
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
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(modelName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(modelDescription)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(Color(white: 0.6))
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(vibrantBlue)
                }
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
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Voice Chip

struct VoiceChip: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    let vibrantBlue = Color(red: 0.36, green: 0.67, blue: 1.0)
    
    var body: some View {
        Button(action: action) {
            Text(name)
                .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                .foregroundColor(isSelected ? .white : Color(white: 0.8))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
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

// MARK: - API Key Preferences

struct APIKeyPreferences: View {
    @EnvironmentObject var appState: AppState
    @State private var apiKeys: [String] = [""]  // Start with one empty slot
    @State private var showKeys: Bool = false
    @State private var statusMessage: String = ""
    @State private var isSuccess: Bool = false
    
    // Explicit colors
    let textWhite = Color.white
    let textGray = Color(white: 0.8)
    let vibrantBlue = Color(red: 0.36, green: 0.67, blue: 1.0)
    let vibrantPurple = Color(red: 0.69, green: 0.46, blue: 1.0)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Info banner
            HStack(spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(vibrantBlue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Groq API Keys")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(textWhite)
                    
                    Text("Add multiple keys for load balancing. Free tier: ~30 req/min, 200 chars/request. Keys rotate automatically.")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(textGray)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(vibrantBlue.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(vibrantBlue.opacity(0.2), lineWidth: 1)
                    )
            )
            
            // API Key inputs - Dynamic list
            PreferenceSection(title: "API Keys (\(apiKeys.filter { !$0.isEmpty }.count) active)", icon: "key.fill") {
                VStack(spacing: 12) {
                    ForEach(Array(apiKeys.enumerated()), id: \.offset) { index, _ in
                        HStack(spacing: 12) {
                            // Key number badge
                            ZStack {
                                if apiKeys[index].isEmpty {
                                    Circle()
                                        .fill(Color.white.opacity(0.05))
                                        .frame(width: 24, height: 24)
                                } else {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [vibrantBlue, vibrantPurple],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 24, height: 24)
                                }
                                
                                Text("\(index + 1)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(apiKeys[index].isEmpty ? Color(white: 0.5) : .white)
                            }
                            
                            // Input field
                            Group {
                                if showKeys {
                                    TextField("gsk_...", text: $apiKeys[index])
                                        .textFieldStyle(.plain)
                                        .foregroundColor(textWhite)
                                } else {
                                    SecureField("gsk_...", text: $apiKeys[index])
                                        .textFieldStyle(.plain)
                                        .foregroundColor(textWhite)
                                }
                            }
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white.opacity(0.08))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(
                                        apiKeys[index].isEmpty ? Color.white.opacity(0.1) : vibrantBlue.opacity(0.3),
                                        lineWidth: 1
                                    )
                            )
                            
                            // Remove button (only show if more than 1 key slot)
                            if apiKeys.count > 1 {
                                Button(action: { removeKey(at: index) }) {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(Color.red.opacity(0.7))
                                }
                                .buttonStyle(.plain)
                                .help("Remove this key slot")
                            }
                        }
                    }
                    
                    // Add key button
                    Button(action: addKeySlot) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 16))
                            Text("Add API Key")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(vibrantBlue)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(vibrantBlue.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(vibrantBlue.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5]))
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    
                    // Action buttons row
                    HStack {
                        Button(action: { showKeys.toggle() }) {
                            HStack(spacing: 6) {
                                Image(systemName: showKeys ? "eye.slash" : "eye")
                                    .font(.system(size: 12))
                                Text(showKeys ? "Hide" : "Show")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(textGray)
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                        
                        // Save button
                        Button(action: saveAPIKeys) {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle")
                                    .font(.system(size: 13))
                                Text("Save Keys")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                LinearGradient(
                                    colors: [vibrantBlue, vibrantPurple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 8)
                    
                    // Status message
                    if !statusMessage.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: isSuccess ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                .foregroundColor(isSuccess ? .green : .red)
                            
                            Text(statusMessage)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(isSuccess ? .green : .red)
                        }
                        .padding(.top, 4)
                    }
                }
            }
            
            // Rate limit info
            PreferenceSection(title: "Groq Free Tier Limits", icon: "speedometer") {
                VStack(alignment: .leading, spacing: 8) {
                    LimitRow(label: "Requests per minute", value: "~30 RPM")
                    LimitRow(label: "Text per request", value: "200 chars max")
                    LimitRow(label: "Audio per hour", value: "~20 min")
                    
                    Text("More keys = better load balancing & fewer rate limit errors")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(Color(white: 0.5))
                        .padding(.top, 4)
                }
            }
            
            // Help text
            PreferenceSection(title: "Alternative Methods", icon: "terminal") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("You can also set keys via:")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(textGray)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        CodeBlock(text: "export GROQ_API_KEY=\"gsk_...\"")
                        CodeBlock(text: "export GROQ_API_KEY_1=\"gsk_...\"")
                    }
                    
                    Text("Or create ~/.flowread/api_keys.json")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(Color(white: 0.6))
                }
            }
        }
        .onAppear { loadAPIKeys() }
    }
    
    private func addKeySlot() {
        withAnimation(.spring(response: 0.3)) {
            apiKeys.append("")
        }
    }
    
    private func removeKey(at index: Int) {
        withAnimation(.spring(response: 0.3)) {
            if apiKeys.count > 1 {
                apiKeys.remove(at: index)
            }
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
                print("Failed to load API keys: \(error)")
            }
        }
    }
    
    private func saveAPIKeys() {
        let configDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".flowread")
        let configPath = configDir.appendingPathComponent("api_keys.json")
        
        do {
            try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
            
            let validKeys = apiKeys.filter { !$0.isEmpty }
            let json: [String: Any] = ["groq_api_keys": validKeys]
            let data = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
            try data.write(to: configPath)
            
            // Reload keys in AppState
            appState.reloadKeys()
            
            statusMessage = "Keys saved successfully!"
            isSuccess = true
        } catch {
            statusMessage = "Failed to save: \(error.localizedDescription)"
            isSuccess = false
        }
    }
}

// MARK: - Reading Preferences

struct ReadingPreferences: View {
    @EnvironmentObject var appState: AppState
    
    // Explicit colors
    let textWhite = Color.white
    let vibrantBlue = Color(red: 0.36, green: 0.67, blue: 1.0)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            PreferenceSection(title: "Typography", icon: "textformat.size") {
                VStack(alignment: .leading, spacing: 20) {
                    // Font size
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Font Size")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(textWhite)
                            
                            Spacer()
                            
                            Text("\(Int(appState.fontSize)) pt")
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .foregroundColor(vibrantBlue)
                        }
                        
                        Slider(value: $appState.fontSize, in: 14...32, step: 1) // Increased max range
                            .tint(vibrantBlue)
                            .onChange(of: appState.fontSize) { _ in appState.saveState() }
                    }
                    
                    // Line spacing
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Line Spacing")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(textWhite)
                            
                            Spacer()
                            
                            Text("\(Int(appState.lineSpacing)) pt")
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .foregroundColor(vibrantBlue)
                        }
                        
                        Slider(value: $appState.lineSpacing, in: 4...24, step: 1)
                            .tint(vibrantBlue)
                            .onChange(of: appState.lineSpacing) { _ in appState.saveState() }
                    }
                }
            }
            
            // Preview
            PreferenceSection(title: "Preview", icon: "eye") {
                Text("The quick brown fox jumps over the lazy dog. This is how your reading experience will look.")
                    .font(.system(size: CGFloat(appState.fontSize), weight: .regular, design: .serif))
                    .lineSpacing(CGFloat(appState.lineSpacing))
                    .foregroundColor(textWhite)
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(red: 0.118, green: 0.141, blue: 0.188))
                    )
            }
        }
    }
}

// MARK: - Helper Views

struct PreferenceSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content
    
    // Explicit colors
    let textWhite = Color.white
    let vibrantBlue = Color(red: 0.36, green: 0.67, blue: 1.0)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(vibrantBlue)
                
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(textWhite)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
            
            // Content
            content()
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                        )
                )
        }
    }
}

struct ToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    
    // Explicit colors
    let textWhite = Color.white
    let textMuted = Color(white: 0.6)
    let vibrantBlue = Color(red: 0.36, green: 0.67, blue: 1.0)
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(textWhite)
                
                Text(subtitle)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(textMuted)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .tint(vibrantBlue)
        }
    }
}

struct CodeBlock: View {
    let text: String
    
    // Explicit colors
    let vibrantBlue = Color(red: 0.36, green: 0.67, blue: 1.0)
    
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundColor(vibrantBlue)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(vibrantBlue.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(vibrantBlue.opacity(0.2), lineWidth: 1)
            )
    }
}

struct LimitRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(Color(white: 0.7))
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(Color(red: 0.36, green: 0.67, blue: 1.0))
        }
    }
}

#Preview {
    PreferencesView()
        .environmentObject(AppState())
}
