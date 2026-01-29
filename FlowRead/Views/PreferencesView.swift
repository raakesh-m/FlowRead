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
                TabButton(title: "Online", icon: "globe", isSelected: selectedTab == 0) {
                    withAnimation(.spring(response: 0.3)) { selectedTab = 0 }
                }
                
                TabButton(title: "Offline", icon: "laptopcomputer", isSelected: selectedTab == 1) {
                    withAnimation(.spring(response: 0.3)) { selectedTab = 1 }
                }
                
                TabButton(title: "Reading", icon: "text.alignleft", isSelected: selectedTab == 2) {
                    withAnimation(.spring(response: 0.3)) { selectedTab = 2 }
                }
                
                TabButton(title: "General", icon: "gearshape", isSelected: selectedTab == 3) {
                    withAnimation(.spring(response: 0.3)) { selectedTab = 3 }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            
            // Tab content
            ScrollView {
                VStack(spacing: 20) {
                    switch selectedTab {
                    case 0:
                        OnlineSettingsView()
                    case 1:
                        OfflineSettingsView(downloadManager: appState.modelDownloadManager)
                    case 2:
                        ReadingPreferences()
                    case 3:
                        GeneralPreferences()
                    default:
                        EmptyView()
                    }
                }
                .padding(24)
            }
            
            Spacer()
        }
        .frame(width: 650, height: 650)
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            PreferenceSection(title: "Application", icon: "app.fill") {
                VStack(alignment: .leading, spacing: 16) {
                    // Global TTS Toggle
                    ToggleRow(
                        title: "Enable Text-to-Speech",
                        subtitle: "Allow FlowRead to read documents aloud",
                        isOn: $appState.isTTSEnabled
                    )
                    .onChange(of: appState.isTTSEnabled) { _ in appState.saveState() }
                    
                    Divider().background(Color.white.opacity(0.1))
                    
                    // Startup
                    ToggleRow(
                        title: "Restore last PDF",
                        subtitle: "Open previous document on launch",
                        isOn: .constant(true) // Placeholder binding
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

// MARK: - Reading Preferences (Updated)

struct ReadingPreferences: View {
    @EnvironmentObject var appState: AppState
    
    let textWhite = Color.white
    let vibrantBlue = Color(red: 0.36, green: 0.67, blue: 1.0)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            
            // Reading Layout/Typography
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
                        Slider(value: $appState.fontSize, in: 14...32, step: 1)
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
            
            // Behavior (Speed, Auto-scroll) - Moved from General
            PreferenceSection(title: "Behavior", icon: "slider.horizontal.3") {
                VStack(alignment: .leading, spacing: 16) {
                    
                    // Playback Speed
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Playback Speed")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(textWhite)
                            Text("Default audio rate")
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
                                        if appState.playbackSpeed == speed { Image(systemName: "checkmark") }
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
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.1)))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(vibrantBlue.opacity(0.3), lineWidth: 1))
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                    }
                    
                    // Auto-scroll
                    ToggleRow(
                        title: "Auto-scroll",
                        subtitle: "Keep current sentence visible",
                        isOn: $appState.autoScrollEnabled
                    )
                    .onChange(of: appState.autoScrollEnabled) { _ in appState.saveState() }
                }
            }
        }
    }
}

// MARK: - Helper Views

struct PreferenceSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content
    
    let textWhite = Color.white
    let vibrantBlue = Color(red: 0.36, green: 0.67, blue: 1.0)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
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
            
            content()
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white.opacity(0.04))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
                )
        }
    }
}

struct ToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    
    let textWhite = Color.white
    let textMuted = Color(white: 0.6)
    let vibrantBlue = Color(red: 0.36, green: 0.67, blue: 1.0)
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 14, weight: .medium)).foregroundColor(textWhite)
                Text(subtitle).font(.system(size: 12, weight: .regular)).foregroundColor(textMuted)
            }
            Spacer()
            Toggle("", isOn: $isOn).toggleStyle(.switch).tint(vibrantBlue)
        }
    }
}

struct CodeBlock: View {
    let text: String
    let vibrantBlue = Color(red: 0.36, green: 0.67, blue: 1.0)
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundColor(vibrantBlue)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 6).fill(vibrantBlue.opacity(0.1)))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(vibrantBlue.opacity(0.2), lineWidth: 1))
    }
}

struct LimitRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label).font(.system(size: 12, weight: .regular)).foregroundColor(Color(white: 0.7))
            Spacer()
            Text(value).font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundColor(Color(red: 0.36, green: 0.67, blue: 1.0))
        }
    }
}

#Preview {
    PreferencesView()
        .environmentObject(AppState())
}
