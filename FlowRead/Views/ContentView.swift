// ContentView.swift
// FlowRead - Main content view with vibrant modern UI

import SwiftUI
import PDFKit

// MARK: - Color Definitions (Inline to ensure they work)
extension Color {
    // Vibrant accent colors
    static let vibrantBlue = Color(red: 0.36, green: 0.67, blue: 1.0)
    static let vibrantPurple = Color(red: 0.69, green: 0.46, blue: 1.0)
    static let vibrantPink = Color(red: 1.0, green: 0.42, blue: 0.62)
    static let vibrantOrange = Color(red: 1.0, green: 0.58, blue: 0.32)
    
    // Background colors
    static let darkBg = Color(red: 0.08, green: 0.09, blue: 0.14)
    static let cardBg = Color(red: 0.11, green: 0.13, blue: 0.18)
    static let surfaceBg = Color(red: 0.14, green: 0.16, blue: 0.22)
    
    // Text colors
    static let textWhite = Color(white: 0.95)
    static let textGray = Color(white: 0.6)
    static let textMuted = Color(white: 0.4)
}

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var showFilePicker = false
    
    var body: some View {
        mainContent
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                handleFileSelection(result)
            }
            .alert("Error", isPresented: $appState.showError) {
                Button("OK") { appState.dismissError() }
            } message: {
                Text(appState.errorMessage ?? "An unknown error occurred.")
            }
            .sheet(isPresented: $appState.showPreferences) {
                PreferencesView()
            }
            .modifier(KeyboardShortcutsModifier(
                appState: appState,
                showFilePicker: $showFilePicker
            ))
    }
    
    @ViewBuilder
    private var mainContent: some View {
        ZStack {
            // Rich gradient background
            LinearGradient(
                stops: [
                    .init(color: Color(red: 0.06, green: 0.07, blue: 0.12), location: 0),
                    .init(color: Color(red: 0.08, green: 0.09, blue: 0.15), location: 0.5),
                    .init(color: Color(red: 0.05, green: 0.06, blue: 0.10), location: 1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // TTS Error Banner
                if let error = appState.ttsManager.lastError {
                    TTSErrorBanner(error: error, onDismiss: {
                        // Error will auto-clear on next successful synthesis
                    })
                }

                // Main content
                if appState.pdfDocument != nil {
                    MainReadingView()
                } else {
                    WelcomeView(showFilePicker: $showFilePicker)
                }
            }

            if appState.isLoading {
                LoadingOverlay(message: appState.loadingMessage)
            }
        }
    }
    
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else { return }
            Task {
                await appState.loadPDF(from: url)
                url.stopAccessingSecurityScopedResource()
            }
        case .failure(let error):
            print("File selection error: \(error)")
        }
    }
}

// MARK: - Keyboard Shortcuts Modifier
struct KeyboardShortcutsModifier: ViewModifier {
    @ObservedObject var appState: AppState
    @Binding var showFilePicker: Bool
    
    func body(content: Content) -> some View {
        content
            // File operations
            .onReceive(NotificationCenter.default.publisher(for: .openPDF)) { _ in
                showFilePicker = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .openPreferences)) { _ in
                appState.showPreferences = true
            }
            // Playback
            .onReceive(NotificationCenter.default.publisher(for: .togglePlayback)) { _ in
                appState.togglePlayback()
            }
            .onReceive(NotificationCenter.default.publisher(for: .stopPlayback)) { _ in
                appState.stop()
            }
            .onReceive(NotificationCenter.default.publisher(for: .nextChunk)) { _ in
                appState.nextChunk()
            }
            .onReceive(NotificationCenter.default.publisher(for: .previousChunk)) { _ in
                appState.previousChunk()
            }
            .onReceive(NotificationCenter.default.publisher(for: .jumpToBeginning)) { _ in
                appState.jumpToBeginning()
            }
            .onReceive(NotificationCenter.default.publisher(for: .jumpToEnd)) { _ in
                appState.jumpToEnd()
            }
            // Speed
            .onReceive(NotificationCenter.default.publisher(for: .increaseSpeed)) { _ in
                appState.increaseSpeed()
            }
            .onReceive(NotificationCenter.default.publisher(for: .decreaseSpeed)) { _ in
                appState.decreaseSpeed()
            }
            .onReceive(NotificationCenter.default.publisher(for: .resetSpeed)) { _ in
                appState.resetSpeed()
            }
            // View
            .onReceive(NotificationCenter.default.publisher(for: .toggleAutoScroll)) { _ in
                appState.toggleAutoScroll()
            }
            .onReceive(NotificationCenter.default.publisher(for: .toggleTTS)) { _ in
                appState.toggleTTS()
            }
            .onReceive(NotificationCenter.default.publisher(for: .increaseFontSize)) { _ in
                appState.increaseFontSize()
            }
            .onReceive(NotificationCenter.default.publisher(for: .decreaseFontSize)) { _ in
                appState.decreaseFontSize()
            }
            .onReceive(NotificationCenter.default.publisher(for: .resetFontSize)) { _ in
                appState.resetFontSize()
            }
    }
}

// MARK: - Welcome View

struct WelcomeView: View {
    @Binding var showFilePicker: Bool
    @State private var isHovering = false
    @State private var pulseAnimation = false
    
    // Responsive breakpoints
    private let compactWidth: CGFloat = 500
    private let mediumWidth: CGFloat = 700
    
    // Gradient for accent colors
    private let accentGradient = LinearGradient(
        colors: [
            Color(red: 0.36, green: 0.67, blue: 1.0),
            Color(red: 0.69, green: 0.46, blue: 1.0),
            Color(red: 1.0, green: 0.42, blue: 0.62)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    var body: some View {
        GeometryReader { geometry in
            let isCompact = geometry.size.width < compactWidth
            let isMedium = geometry.size.width < mediumWidth
            
            // Responsive sizes
            let iconSize: CGFloat = isCompact ? 80 : (isMedium ? 100 : 120)
            let iconFontSize: CGFloat = isCompact ? 32 : (isMedium ? 40 : 48)
            let titleFontSize: CGFloat = isCompact ? 32 : (isMedium ? 42 : 52)
            let taglineFontSize: CGFloat = isCompact ? 12 : (isMedium ? 15 : 18)
            let buttonFontSize: CGFloat = isCompact ? 14 : (isMedium ? 15 : 17)
            let ringCount = isCompact ? 2 : 3
            
            VStack(spacing: isCompact ? 30 : (isMedium ? 40 : 50)) {
                Spacer()
                
                // Logo and title
                VStack(spacing: isCompact ? 16 : 24) {
                    // Animated icon with glow
                    ZStack {
                        // Outer glow rings
                        ForEach(0..<ringCount, id: \.self) { i in
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.36, green: 0.67, blue: 1.0).opacity(0.3 - Double(i) * 0.1),
                                            Color(red: 0.69, green: 0.46, blue: 1.0).opacity(0.2 - Double(i) * 0.05)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: isCompact ? 1.5 : 2
                                )
                                .frame(width: iconSize + 10 + CGFloat(i * (isCompact ? 12 : 20)), height: iconSize + 10 + CGFloat(i * (isCompact ? 12 : 20)))
                                .opacity(pulseAnimation ? 0.8 : 0.3)
                        }
                        
                        // Main circle with gradient border
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.14, green: 0.16, blue: 0.22),
                                        Color(red: 0.10, green: 0.11, blue: 0.16)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: iconSize, height: iconSize)
                            .overlay(
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.36, green: 0.67, blue: 1.0),
                                                Color(red: 0.69, green: 0.46, blue: 1.0)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: isCompact ? 1.5 : 2
                                    )
                            )
                            .shadow(color: Color(red: 0.36, green: 0.67, blue: 1.0).opacity(0.4), radius: isCompact ? 15 : 30, y: isCompact ? 3 : 5)
                        
                        // Book icon
                        Image(systemName: "book.pages.fill")
                            .font(.system(size: iconFontSize, weight: .medium))
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
                    .onAppear {
                        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                            pulseAnimation = true
                        }
                    }
                    
                    // App name with gradient text
                    Text("FlowRead")
                        .font(.system(size: titleFontSize, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, Color(white: 0.85)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: .black.opacity(0.3), radius: 2, y: 2)
                    
                    // Tagline with gradient
                    Text(isCompact ? "Read • Listen • Flow" : "Read  •  Listen  •  Flow")
                        .font(.system(size: taglineFontSize, weight: .medium, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.36, green: 0.67, blue: 1.0),
                                    Color(red: 0.69, green: 0.46, blue: 1.0)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .tracking(isCompact ? 1.5 : 3)
                }
                
                // Open PDF button with vibrant gradient
                Button(action: { showFilePicker = true }) {
                    HStack(spacing: isCompact ? 8 : 14) {
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: isCompact ? 16 : 20, weight: .semibold))
                        Text("Open PDF")
                            .font(.system(size: buttonFontSize, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, isCompact ? 24 : 40)
                    .padding(.vertical, isCompact ? 12 : 18)
                    .background(
                        ZStack {
                            // Main gradient
                            RoundedRectangle(cornerRadius: isCompact ? 12 : 16)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.36, green: 0.67, blue: 1.0),
                                            Color(red: 0.55, green: 0.45, blue: 1.0),
                                            Color(red: 0.85, green: 0.40, blue: 0.75)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                            
                            // Top shine
                            RoundedRectangle(cornerRadius: isCompact ? 12 : 16)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.25), Color.clear],
                                        startPoint: .top,
                                        endPoint: .center
                                    )
                                )
                        }
                    )
                    .shadow(color: Color(red: 0.36, green: 0.67, blue: 1.0).opacity(isHovering ? 0.7 : 0.5), radius: isHovering ? (isCompact ? 15 : 25) : (isCompact ? 8 : 15), y: isCompact ? 4 : 8)
                    .scaleEffect(isHovering ? 1.05 : 1.0)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isHovering = hovering
                    }
                }
                
                Spacer()
                
                // Keyboard shortcuts (hide on very compact screens)
                if !isCompact {
                    VStack(spacing: isMedium ? 8 : 10) {
                        KeyboardHint(key: "⌘O", action: "Open PDF", isCompact: isMedium)
                        KeyboardHint(key: "⌘,", action: "Preferences", isCompact: isMedium)
                    }
                    .padding(.bottom, isCompact ? 20 : 40)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Keyboard Hint

struct KeyboardHint: View {
    let key: String
    let action: String
    var isCompact: Bool = false
    
    var body: some View {
        HStack(spacing: isCompact ? 6 : 10) {
            Text(key)
                .font(.system(size: isCompact ? 11 : 13, weight: .semibold, design: .monospaced))
                .foregroundColor(Color(red: 0.36, green: 0.67, blue: 1.0))
                .padding(.horizontal, isCompact ? 8 : 10)
                .padding(.vertical, isCompact ? 4 : 5)
                .background(
                    RoundedRectangle(cornerRadius: isCompact ? 6 : 8)
                        .fill(Color(red: 0.36, green: 0.67, blue: 1.0).opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: isCompact ? 6 : 8)
                                .stroke(Color(red: 0.36, green: 0.67, blue: 1.0).opacity(0.3), lineWidth: 1)
                        )
                )
            
            Text(action)
                .font(.system(size: isCompact ? 11 : 13, weight: .medium))
                .foregroundColor(Color(white: 0.5))
        }
    }
}

// MARK: - Loading Overlay

struct LoadingOverlay: View {
    let message: String
    @State private var rotation: Double = 0
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Gradient spinner
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 4)
                        .frame(width: 50, height: 50)
                    
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.36, green: 0.67, blue: 1.0),
                                    Color(red: 0.69, green: 0.46, blue: 1.0)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 50, height: 50)
                        .rotationEffect(.degrees(rotation))
                        .onAppear {
                            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                                rotation = 360
                            }
                        }
                }
                
                Text(message)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(red: 0.11, green: 0.13, blue: 0.18).opacity(0.95))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.36, green: 0.67, blue: 1.0).opacity(0.3),
                                        Color(red: 0.69, green: 0.46, blue: 1.0).opacity(0.2)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
            .shadow(color: Color(red: 0.36, green: 0.67, blue: 1.0).opacity(0.3), radius: 30, y: 10)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
        .frame(width: 900, height: 700)
}
