// MainReadingView.swift
// FlowRead - Main reading interface with vibrant modern design

import SwiftUI

struct MainReadingView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 0) {
            TopToolbar()
            ReadingPane()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            PlaybackControlBar()
        }
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.07, blue: 0.12),
                    Color(red: 0.08, green: 0.09, blue: 0.14)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

// MARK: - Top Toolbar

struct TopToolbar: View {
    @EnvironmentObject var appState: AppState
    
    // Responsive breakpoints
    private let compactWidth: CGFloat = 500
    private let mediumWidth: CGFloat = 700
    
    var body: some View {
        GeometryReader { geometry in
            let isCompact = geometry.size.width < compactWidth
            let isMedium = geometry.size.width < mediumWidth
            
            HStack(spacing: isMedium ? 10 : 16) {
                // Document info
                if let url = appState.pdfURL {
                    HStack(spacing: isMedium ? 8 : 12) {
                        // PDF icon with gradient
                        ZStack {
                            RoundedRectangle(cornerRadius: isMedium ? 8 : 10)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.36, green: 0.67, blue: 1.0).opacity(0.2),
                                            Color(red: 0.69, green: 0.46, blue: 1.0).opacity(0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: isMedium ? 32 : 40, height: isMedium ? 32 : 40)
                            
                            Image(systemName: "doc.fill")
                                .font(.system(size: isMedium ? 14 : 18, weight: .medium))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.36, green: 0.67, blue: 1.0),
                                            Color(red: 0.69, green: 0.46, blue: 1.0)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        }
                        
                        if !isCompact {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(url.deletingPathExtension().lastPathComponent)
                                    .font(.system(size: isMedium ? 13 : 15, weight: .semibold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                
                                Text("\(appState.textChunks.count) sentences")
                                    .font(.system(size: isMedium ? 10 : 12, weight: .medium))
                                    .foregroundColor(Color(white: 0.5))
                            }
                            .frame(maxWidth: isMedium ? 120 : 200, alignment: .leading)
                        }
                    }
                }
                
                Spacer(minLength: 4)
                
                // Progress indicator
                if !appState.textChunks.isEmpty {
                    ProgressIndicator(isCompact: isCompact, isMedium: isMedium)
                }
                
                Spacer(minLength: 4)
                
                // Toolbar buttons
                HStack(spacing: isMedium ? 6 : 10) {
                    // NEW: TTS Toggle Button (Moved from Control Panel)
                    ToolbarButton(
                        icon: appState.isTTSEnabled ? "waveform.circle.fill" : "waveform.circle",
                        isActive: appState.isTTSEnabled,
                        tooltip: "Text-to-Speech",
                        size: isMedium ? 32 : 40,
                        activeColor: Color.blue // Or custom color if preferred
                    ) {
                        appState.isTTSEnabled.toggle()
                        appState.saveState()
                    }
                    
                    ToolbarButton(
                        icon: appState.autoScrollEnabled ? "arrow.down.circle.fill" : "arrow.down.circle",
                        isActive: appState.autoScrollEnabled,
                        tooltip: "Auto-scroll",
                        size: isMedium ? 32 : 40
                    ) {
                        withAnimation(.spring(response: 0.3)) {
                            appState.autoScrollEnabled.toggle()
                            appState.saveState()
                        }
                    }
                    
                    if !isCompact {
                        Divider()
                            .frame(height: isMedium ? 20 : 24)
                            .padding(.horizontal, isMedium ? 2 : 4)
                    }
                    
                    ToolbarButton(icon: "folder", tooltip: "Open PDF", size: isMedium ? 32 : 40) {
                        // Use NotificationCenter to trigger file picker in ContentView
                        // This is more reliable than local state in nested views
                        NotificationCenter.default.post(name: .openPDF, object: nil)
                    }
                    
                    ToolbarButton(icon: "gearshape", tooltip: "Preferences", size: isMedium ? 32 : 40) {
                        appState.showPreferences = true
                    }
                }
            }
            .padding(.horizontal, isCompact ? 12 : (isMedium ? 16 : 24))
            .padding(.vertical, isMedium ? 12 : 16)
            .frame(maxWidth: .infinity)
        }
        .frame(height: 72)
        .background(
            ZStack {
                Color(red: 0.10, green: 0.12, blue: 0.17)
                
                // Subtle gradient overlay
                LinearGradient(
                    colors: [Color.white.opacity(0.03), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        )
        .overlay(
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.36, green: 0.67, blue: 1.0).opacity(0.3),
                            Color(red: 0.69, green: 0.46, blue: 1.0).opacity(0.2),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1),
            alignment: .bottom
        )
    }
}

// MARK: - Progress Indicator

struct ProgressIndicator: View {
    @EnvironmentObject var appState: AppState
    var isCompact: Bool = false
    var isMedium: Bool = false
    
    private var progress: Double {
        guard !appState.textChunks.isEmpty else { return 0 }
        return Double(appState.currentChunkIndex + 1) / Double(appState.textChunks.count)
    }
    
    private var barWidth: CGFloat {
        isCompact ? 80 : (isMedium ? 120 : 200)
    }
    
    var body: some View {
        HStack(spacing: isCompact ? 8 : (isMedium ? 10 : 16)) {
            // Progress bar with gradient
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: isCompact ? 3 : 4)
                        .fill(Color.white.opacity(0.1))
                    
                    RoundedRectangle(cornerRadius: isCompact ? 3 : 4)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.36, green: 0.67, blue: 1.0),
                                    Color(red: 0.69, green: 0.46, blue: 1.0)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progress)
                        .shadow(color: Color(red: 0.36, green: 0.67, blue: 1.0).opacity(0.5), radius: isCompact ? 2 : 4, y: 0)
                        .animation(.spring(response: 0.3), value: progress)
                }
            }
            .frame(width: barWidth, height: isCompact ? 4 : 6)
            
            Text(isCompact ? "\(appState.currentChunkIndex + 1)/\(appState.textChunks.count)" : "\(appState.currentChunkIndex + 1) / \(appState.textChunks.count)")
                .font(.system(size: isCompact ? 10 : (isMedium ? 11 : 13), weight: .semibold, design: .monospaced))
                .foregroundColor(Color(red: 0.36, green: 0.67, blue: 1.0))
        }
    }
}

// MARK: - Toolbar Button

struct ToolbarButton: View {
    let icon: String
    var isActive: Bool = false
    var tooltip: String = ""
    var size: CGFloat = 40
    var activeColor: Color = Color(red: 0.36, green: 0.67, blue: 1.0)
    let action: () -> Void
    
    @State private var isHovered = false
    
    private var iconSize: CGFloat {
        size < 36 ? 12 : (size < 40 ? 14 : 16)
    }
    
    private var cornerRadius: CGFloat {
        size < 36 ? 8 : (size < 40 ? 10 : 12)
    }
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .medium))
                .foregroundColor(
                    isActive ? activeColor :
                    (isHovered ? .white : Color(white: 0.6))
                )
                .frame(width: size, height: size)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            isActive ? activeColor.opacity(0.15) :
                            (isHovered ? Color.white.opacity(0.1) : Color.clear)
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            isActive ? activeColor.opacity(0.4) : Color.clear,
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
        .help(tooltip)
        .onHover { isHovered = $0 }
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .animation(.spring(response: 0.2), value: isHovered)
    }
}

#Preview {
    MainReadingView()
        .environmentObject(AppState())
        .frame(width: 900, height: 600)
}
