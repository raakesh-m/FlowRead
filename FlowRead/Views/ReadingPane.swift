// ReadingPane.swift
// FlowRead - Text reading pane with vibrant highlighting

import SwiftUI

struct ReadingPane: View {
    @EnvironmentObject var appState: AppState
    @State private var scrollProxy: ScrollViewProxy?
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    Spacer().frame(height: 24)
                    
                    ForEach(Array(appState.textChunks.enumerated()), id: \.element.id) { index, chunk in
                        TextChunkView(
                            chunk: chunk,
                            index: index,
                            isActive: index == appState.currentChunkIndex,
                            isPlayed: index < appState.currentChunkIndex
                        )
                        .id(chunk.id)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3)) {
                                appState.jumpToChunk(index)
                            }
                        }
                    }
                    
                    Spacer().frame(height: 120)
                }
                .padding(.horizontal, 60)
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

// MARK: - Text Chunk View

struct TextChunkView: View {
    let chunk: TextChunk
    let index: Int
    let isActive: Bool

    let isPlayed: Bool
    
    @EnvironmentObject var appState: AppState
    @State private var isHovered = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            // Line number with indicator
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
            
            // Text content
            Text(chunk.text)
                .font(.system(size: CGFloat(appState.fontSize), weight: .regular, design: .serif))
                .foregroundColor(textColor)
                .lineSpacing(CGFloat(appState.lineSpacing))
                .tracking(0.3)
                .padding(.horizontal, 24)
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    ZStack {
                        // Card background
                        RoundedRectangle(cornerRadius: 14)
                            .fill(backgroundColor)
                        
                        // Active glow
                        if isActive {
                            RoundedRectangle(cornerRadius: 14)
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
                        RoundedRectangle(cornerRadius: 14)
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
                                lineWidth: isActive ? 2 : 0
                            )
                    }
                )
                .shadow(
                    color: isActive ? Color(red: 0.36, green: 0.67, blue: 1.0).opacity(0.2) : Color.clear,
                    radius: isActive ? 20 : 0,
                    y: 5
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
