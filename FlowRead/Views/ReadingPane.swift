// ReadingPane.swift
// FlowRead - Text reading pane with vibrant highlighting

import SwiftUI

struct ReadingPane: View {
    @EnvironmentObject var appState: AppState
    @State private var scrollProxy: ScrollViewProxy?
    @State private var userScrolledRecently: Bool = false
    @State private var userScrollTimer: Timer? = nil
    @State private var lastKnownChunkIndex: Int = 0
    
    // Responsive breakpoints
    private let compactWidth: CGFloat = 500
    private let mediumWidth: CGFloat = 800
    
    // Time before auto-scroll resumes after user interaction (seconds)
    private let scrollPauseDelay: TimeInterval = 2.5
    
    var body: some View {
        GeometryReader { geometry in
            let isCompact = geometry.size.width < compactWidth
            let isMedium = geometry.size.width < mediumWidth
            let horizontalPadding: CGFloat = isCompact ? 16 : (isMedium ? 30 : 60)
            
            ZStack(alignment: .top) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: isCompact ? 10 : 14) {
                            // Top padding to allow scrolling first item to upper portion
                            Spacer().frame(height: isCompact ? 16 : 24)
                            
                            ForEach(Array(appState.textChunks.enumerated()), id: \.element.id) { index, chunk in
                                TextChunkView(
                                    chunk: chunk,
                                    index: index,
                                    isActive: index == appState.currentChunkIndex,
                                    isPlayed: index < appState.currentChunkIndex,
                                    isCompact: isCompact
                                )
                                .id(chunk.id)
                                .onTapGesture {
                                    // User tapped a chunk - this is intentional navigation, not scroll
                                    withAnimation(.spring(response: 0.3)) {
                                        appState.jumpToChunk(index)
                                    }
                                }
                            }
                            
                            // Bottom padding for comfortable scrolling of last items
                            Spacer().frame(height: isCompact ? 80 : 120)
                        }
                        .padding(.horizontal, horizontalPadding)
                        // Detect user scroll gestures
                        .background(
                            GeometryReader { contentGeo in
                                Color.clear
                                    .preference(key: ScrollOffsetPreferenceKey.self, value: contentGeo.frame(in: .named("scrollView")).minY)
                            }
                        )
                    }
                    .coordinateSpace(name: "scrollView")
                    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { _ in
                        // User is scrolling manually - pause auto-scroll temporarily
                        if appState.isPlaying && appState.autoScrollEnabled {
                            onUserScroll()
                        }
                    }
                    .background(Color(red: 0.07, green: 0.08, blue: 0.12))
                    .onChange(of: appState.currentChunkIndex) { newIndex in
                        // Chunk changed - always resume auto-scroll behavior
                        // This is the "smart" part: user expects to follow along when new sentence starts
                        if appState.autoScrollEnabled && !userScrolledRecently {
                            scrollToCurrentChunk(proxy: proxy, index: newIndex, animated: true)
                        } else if appState.autoScrollEnabled && userScrolledRecently {
                            // User scrolled recently, but chunk changed - resume scrolling
                            // Clear the pause state for smoother experience
                            clearUserScrollState()
                            scrollToCurrentChunk(proxy: proxy, index: newIndex, animated: true)
                        }
                        lastKnownChunkIndex = newIndex
                    }
                    .onAppear {
                        scrollProxy = proxy
                        lastKnownChunkIndex = appState.currentChunkIndex
                    }
                }
                
                // Scroll status indicator (shows when user scroll paused auto-follow)
                if appState.isPlaying && userScrolledRecently && appState.autoScrollEnabled {
                    ScrollStatusBadge(message: "Scroll paused • Will resume on next sentence")
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.easeInOut(duration: 0.3), value: userScrolledRecently)
                }
            }
        }
    }
    
    /// Handle user manual scroll - pause auto-scroll temporarily
    private func onUserScroll() {
        // Mark that user scrolled
        userScrolledRecently = true
        
        // Cancel any existing timer
        userScrollTimer?.invalidate()
        
        // Set a timer to reset after delay (but chunk change will also reset it)
        userScrollTimer = Timer.scheduledTimer(withTimeInterval: scrollPauseDelay, repeats: false) { _ in
            Task { @MainActor in
                userScrolledRecently = false
            }
        }
    }
    
    /// Clear user scroll state (called when chunk changes)
    private func clearUserScrollState() {
        userScrollTimer?.invalidate()
        userScrollTimer = nil
        userScrolledRecently = false
    }
    
    /// Scroll to the current chunk with smart positioning
    private func scrollToCurrentChunk(proxy: ScrollViewProxy, index: Int, animated: Bool) {
        guard index < appState.textChunks.count else { return }
        
        let chunkId = appState.textChunks[index].id
        
        // Use .top anchor with a small offset to position in upper ~30% of screen
        // This is more comfortable for reading than dead center
        let scrollAction = {
            proxy.scrollTo(chunkId, anchor: UnitPoint(x: 0.5, y: 0.25))
        }
        
        if animated {
            withAnimation(.easeInOut(duration: 0.4)) {
                scrollAction()
            }
        } else {
            scrollAction()
        }
    }
}

// MARK: - Scroll Offset Preference Key

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Scroll Status Badge

struct ScrollStatusBadge: View {
    let message: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(red: 1.0, green: 0.8, blue: 0.3))
            
            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(white: 0.9))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color(red: 0.15, green: 0.16, blue: 0.22).opacity(0.95))
                .shadow(color: Color.black.opacity(0.3), radius: 8, y: 4)
        )
        .overlay(
            Capsule()
                .stroke(Color(red: 1.0, green: 0.8, blue: 0.3).opacity(0.3), lineWidth: 1)
        )
        .padding(.top, 12)
    }
}

// MARK: - Text Chunk View

struct TextChunkView: View {
    let chunk: TextChunk
    let index: Int
    let isActive: Bool
    let isPlayed: Bool
    var isCompact: Bool = false
    
    @EnvironmentObject var appState: AppState
    @State private var isHovered = false
    
    private var effectiveFontSize: CGFloat {
        let baseFontSize = CGFloat(appState.fontSize)
        return isCompact ? max(baseFontSize - 2, 14) : baseFontSize
    }
    
    private var horizontalPadding: CGFloat {
        isCompact ? 14 : 24
    }
    
    private var verticalPadding: CGFloat {
        isCompact ? 12 : 18
    }
    
    private var cornerRadius: CGFloat {
        isCompact ? 10 : 14
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: isCompact ? 10 : 20) {
            // Line number with indicator (hide on very compact)
            if !isCompact {
                VStack(spacing: 6) {
                    Text("\(index + 1)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(
                            isActive ? Color(red: 0.36, green: 0.67, blue: 1.0) : Color(white: 0.35)
                        )
                    
                    if isActive {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.36, green: 0.67, blue: 1.0),
                                        Color(red: 0.69, green: 0.46, blue: 1.0)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 8, height: 8)
                            .shadow(color: Color(red: 0.36, green: 0.67, blue: 1.0).opacity(0.8), radius: 4)
                    }
                }
                .frame(width: 40, alignment: .trailing)
                .opacity(isActive || isHovered ? 1 : 0.6)
            }
            
            // Text content
            VStack(alignment: .leading, spacing: 0) {
                // Compact mode: show line number inline
                if isCompact {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(
                                isActive ?
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.36, green: 0.67, blue: 1.0),
                                        Color(red: 0.69, green: 0.46, blue: 1.0)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ) :
                                LinearGradient(colors: [Color(white: 0.4)], startPoint: .leading, endPoint: .trailing)
                            )
                            .frame(width: 6, height: 6)
                        
                        Text("#\(index + 1)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(
                                isActive ? Color(red: 0.36, green: 0.67, blue: 1.0) : Color(white: 0.4)
                            )
                    }
                    .padding(.bottom, 6)
                }
                
                Text(chunk.text)
                    .font(.system(size: effectiveFontSize, weight: .regular, design: .serif))
                    .foregroundColor(textColor)
                    .lineSpacing(CGFloat(appState.lineSpacing))
                    .tracking(isCompact ? 0.2 : 0.3)
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack {
                    // Card background
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(backgroundColor)
                    
                    // Active glow
                    if isActive {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.36, green: 0.67, blue: 1.0).opacity(0.08),
                                        Color(red: 0.69, green: 0.46, blue: 1.0).opacity(0.04)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    
                    // Border
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            isActive ?
                            LinearGradient(
                                colors: [
                                    Color(red: 0.36, green: 0.67, blue: 1.0),
                                    Color(red: 0.69, green: 0.46, blue: 1.0)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ) :
                            LinearGradient(colors: [Color.clear], startPoint: .leading, endPoint: .trailing),
                            lineWidth: isActive ? (isCompact ? 1.5 : 2) : 0
                        )
                }
            )
            .shadow(
                color: isActive ? Color(red: 0.36, green: 0.67, blue: 1.0).opacity(0.2) : Color.clear,
                radius: isActive ? (isCompact ? 12 : 20) : 0,
                y: isCompact ? 3 : 5
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isActive)
        }
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .cursor(isHovered ? .pointingHand : .arrow)
    }
    
    private var textColor: Color {
        if isActive {
            return .white
        } else if isPlayed {
            return Color(white: 0.5)
        } else {
            return Color(white: 0.85)
        }
    }
    
    private var backgroundColor: Color {
        if isHovered && !isActive {
            return Color.white.opacity(0.03)
        }
        return Color.clear
    }
}

// MARK: - Cursor Extension

extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        self.onHover { hovering in
            if hovering {
                cursor.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

#Preview {
    ReadingPane()
        .environmentObject(AppState())
        .frame(width: 700, height: 500)
}
