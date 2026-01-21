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
            
            if appState.pdfDocument != nil {
                MainReadingView()
            } else {
                WelcomeView(showFilePicker: $showFilePicker)
            }
            
            if appState.isLoading {
                LoadingOverlay(message: appState.loadingMessage)
            }
        }
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
        .onReceive(NotificationCenter.default.publisher(for: .openPDF)) { _ in
            showFilePicker = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .openPreferences)) { _ in
            appState.showPreferences = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .togglePlayback)) { _ in
            appState.togglePlayback()
        }
        .onReceive(NotificationCenter.default.publisher(for: .nextChunk)) { _ in
            appState.nextChunk()
        }
        .onReceive(NotificationCenter.default.publisher(for: .previousChunk)) { _ in
            appState.previousChunk()
        }
        .onReceive(NotificationCenter.default.publisher(for: .increaseSpeed)) { _ in
            appState.increaseSpeed()
        }
        .onReceive(NotificationCenter.default.publisher(for: .decreaseSpeed)) { _ in
            appState.decreaseSpeed()
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

// MARK: - Welcome View

struct WelcomeView: View {
    @Binding var showFilePicker: Bool
    @State private var isHovering = false
    @State private var pulseAnimation = false
    
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
        VStack(spacing: 50) {
            Spacer()
            
            // Logo and title
            VStack(spacing: 24) {
                // Animated icon with glow
                ZStack {
                    // Outer glow rings
                    ForEach(0..<3) { i in
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
                                lineWidth: 2
                            )
                            .frame(width: 130 + CGFloat(i * 20), height: 130 + CGFloat(i * 20))
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
                        .frame(width: 120, height: 120)
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
                                    lineWidth: 2
                                )
                        )
                        .shadow(color: Color(red: 0.36, green: 0.67, blue: 1.0).opacity(0.4), radius: 30, y: 5)
                    
                    // Book icon
                    Image(systemName: "book.pages.fill")
                        .font(.system(size: 48, weight: .medium))
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
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, Color(white: 0.85)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: .black.opacity(0.3), radius: 2, y: 2)
                
                // Tagline with gradient
                Text("Read  •  Listen  •  Flow")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
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
                    .tracking(3)
            }
            
            // Open PDF button with vibrant gradient
            Button(action: { showFilePicker = true }) {
                HStack(spacing: 14) {
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 20, weight: .semibold))
                    Text("Open PDF")
                        .font(.system(size: 17, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 40)
                .padding(.vertical, 18)
                .background(
                    ZStack {
                        // Main gradient
                        RoundedRectangle(cornerRadius: 16)
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
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.25), Color.clear],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                    }
                )
                .shadow(color: Color(red: 0.36, green: 0.67, blue: 1.0).opacity(isHovering ? 0.7 : 0.5), radius: isHovering ? 25 : 15, y: 8)
                .scaleEffect(isHovering ? 1.05 : 1.0)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isHovering = hovering
                }
            }
            
            Spacer()
            
            // Keyboard shortcuts
            VStack(spacing: 10) {
                KeyboardHint(key: "⌘O", action: "Open PDF")
                KeyboardHint(key: "⌘,", action: "Preferences (Add API Keys)")
            }
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Keyboard Hint

struct KeyboardHint: View {
    let key: String
    let action: String
    
    var body: some View {
        HStack(spacing: 10) {
            Text(key)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(Color(red: 0.36, green: 0.67, blue: 1.0))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(red: 0.36, green: 0.67, blue: 1.0).opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(red: 0.36, green: 0.67, blue: 1.0).opacity(0.3), lineWidth: 1)
                        )
                )
            
            Text(action)
                .font(.system(size: 13, weight: .medium))
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
