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
    @State private var showFilePicker = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Document info
            if let url = appState.pdfURL {
                HStack(spacing: 12) {
                    // PDF icon with gradient
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
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
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: "doc.fill")
                            .font(.system(size: 18, weight: .medium))
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
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text(url.deletingPathExtension().lastPathComponent)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Text("\(appState.textChunks.count) sentences")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(white: 0.5))
                    }
                }
            }
            
            Spacer()
            
            // Progress indicator
            if !appState.textChunks.isEmpty {
                ProgressIndicator()
            }
            
            Spacer()
            
            // Toolbar buttons
            HStack(spacing: 10) {
                ToolbarButton(
                    icon: appState.autoScrollEnabled ? "arrow.down.circle.fill" : "arrow.down.circle",
                    isActive: appState.autoScrollEnabled,
                    tooltip: "Auto-scroll"
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        appState.autoScrollEnabled.toggle()
                        appState.saveState()
                    }
                }
                
                Divider()
                    .frame(height: 24)
                    .padding(.horizontal, 4)
                
                ToolbarButton(icon: "folder", tooltip: "Open PDF") {
                    showFilePicker = true
                }
                
                ToolbarButton(icon: "gearshape", tooltip: "Preferences") {
                    appState.showPreferences = true
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
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
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                guard url.startAccessingSecurityScopedResource() else { return }
                Task {
                    await appState.loadPDF(from: url)
                    url.stopAccessingSecurityScopedResource()
                }
            }
        }
    }
}

// MARK: - Progress Indicator

struct ProgressIndicator: View {
    @EnvironmentObject var appState: AppState
    
    private var progress: Double {
        guard !appState.textChunks.isEmpty else { return 0 }
        return Double(appState.currentChunkIndex + 1) / Double(appState.textChunks.count)
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Progress bar with gradient
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))
                    
                    RoundedRectangle(cornerRadius: 4)
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
                        .shadow(color: Color(red: 0.36, green: 0.67, blue: 1.0).opacity(0.5), radius: 4, y: 0)
                        .animation(.spring(response: 0.3), value: progress)
                }
            }
            .frame(width: 200, height: 6)
            
            Text("\(appState.currentChunkIndex + 1) / \(appState.textChunks.count)")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(Color(red: 0.36, green: 0.67, blue: 1.0))
        }
    }
}

// MARK: - Toolbar Button

struct ToolbarButton: View {
    let icon: String
    var isActive: Bool = false
    var tooltip: String = ""
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(
                    isActive ? Color(red: 0.36, green: 0.67, blue: 1.0) :
                    (isHovered ? .white : Color(white: 0.6))
                )
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            isActive ? Color(red: 0.36, green: 0.67, blue: 1.0).opacity(0.15) :
                            (isHovered ? Color.white.opacity(0.1) : Color.clear)
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isActive ? Color(red: 0.36, green: 0.67, blue: 1.0).opacity(0.4) : Color.clear,
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
