// ReadingPane.swift
// FlowRead - Text reading pane with vibrant highlighting

import SwiftUI

struct ReadingPane: View {
    @EnvironmentObject var appState: AppState
    @State private var scrollProxy: ScrollViewProxy?
    
    // Responsive breakpoints
    private let compactWidth: CGFloat = 500
    private let mediumWidth: CGFloat = 800
    
    var body: some View {
        GeometryReader { geometry in
            let isCompact = geometry.size.width < compactWidth
            let isMedium = geometry.size.width < mediumWidth
            let horizontalPadding: CGFloat = isCompact ? 16 : (isMedium ? 30 : 60)
            
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: isCompact ? 10 : 14) {
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
                                withAnimation(.spring(response: 0.3)) {
                                    appState.jumpToChunk(index)
                                }
                            }
                        }
                        
                        Spacer().frame(height: isCompact ? 80 : 120)
                    }
                    .padding(.horizontal, horizontalPadding)
                }
                .background(Color(red: 0.07, green: 0.08, blue: 0.12))
                .onChange(of: appState.currentChunkIndex) { newIndex in
                    if appState.autoScrollEnabled {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            if newIndex < appState.textChunks.count {
                                proxy.scrollTo(appState.textChunks[newIndex].id, anchor: .center)
                            }
                        }
                    }
                }
                .onAppear { scrollProxy = proxy }
            }
        }
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
