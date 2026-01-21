// PlaybackControlBar.swift
// FlowRead - Vibrant playback control bar

import SwiftUI

struct PlaybackControlBar: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack(spacing: 24) {
            CurrentChunkInfo()
                .frame(maxWidth: 300, alignment: .leading)
            
            Spacer()
            
            PlaybackControls()
            
            Spacer()
            
            SpeedControl()
                .frame(maxWidth: 200, alignment: .trailing)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 20)
        .background(
            ZStack {
                Color(red: 0.10, green: 0.12, blue: 0.17)
                
                // Top gradient border
                LinearGradient(
                    colors: [
                        Color(red: 0.36, green: 0.67, blue: 1.0).opacity(0.2),
                        Color(red: 0.69, green: 0.46, blue: 1.0).opacity(0.1),
                        Color.clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 1)
                .frame(maxHeight: .infinity, alignment: .top)
            }
        )
    }
}

// MARK: - Current Chunk Info

struct CurrentChunkInfo: View {
    @EnvironmentObject var appState: AppState
    
    private var currentChunk: TextChunk? {
        let index = appState.currentChunkIndex
        guard index >= 0, index < appState.textChunks.count else { return nil }
        return appState.textChunks[index]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let chunk = currentChunk {
                HStack(spacing: 8) {
                    // Animated dot
                    Circle()
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
                        .frame(width: 8, height: 8)
                        .shadow(color: Color(red: 0.36, green: 0.67, blue: 1.0).opacity(0.8), radius: 4)
                    
                    Text("Page \(chunk.pageIndex + 1) • Sentence \(appState.currentChunkIndex + 1)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(red: 0.36, green: 0.67, blue: 1.0))
                        .textCase(.uppercase)
                        .tracking(1)
                }
                
                Text(chunk.text.prefix(55) + (chunk.text.count > 55 ? "..." : ""))
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(Color(white: 0.7))
                    .lineLimit(1)
            } else {
                Text("No content")
                    .font(.system(size: 13))
                    .foregroundColor(Color(white: 0.4))
            }
        }
    }
}

// MARK: - Playback Controls

struct PlaybackControls: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack(spacing: 28) {
            ControlButton(
                icon: "backward.fill",
                size: 18,
                action: { appState.previousChunk() },
                disabled: appState.currentChunkIndex == 0
            )
            
            PlayPauseButton()
            
            ControlButton(
                icon: "forward.fill",
                size: 18,
                action: { appState.nextChunk() },
                disabled: appState.currentChunkIndex >= appState.textChunks.count - 1
            )
        }
    }
}

// MARK: - Play/Pause Button

struct PlayPauseButton: View {
    @EnvironmentObject var appState: AppState
    @State private var isHovered = false
    @State private var isPressed = false
    
    var body: some View {
        Button(action: { appState.togglePlayback() }) {
            ZStack {
                // Outer glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.36, green: 0.67, blue: 1.0).opacity(isHovered ? 0.4 : 0.2),
                                Color(red: 0.69, green: 0.46, blue: 1.0).opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 25,
                            endRadius: 60
                        )
                    )
                    .frame(width: 100, height: 100)
                
                // Main button with gradient
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.36, green: 0.67, blue: 1.0),
                                Color(red: 0.55, green: 0.45, blue: 1.0),
                                Color(red: 0.69, green: 0.46, blue: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 68, height: 68)
                    .overlay(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.3), Color.clear],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                    )
                    .shadow(color: Color(red: 0.36, green: 0.67, blue: 1.0).opacity(0.5), radius: 15, y: 5)
                
                // Icon
                Image(systemName: appState.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)
                    .offset(x: appState.isPlaying ? 0 : 3)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.92 : (isHovered ? 1.08 : 1.0))
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isHovered)
        .animation(.spring(response: 0.15), value: isPressed)
        .onHover { isHovered = $0 }
        .pressEvents(onPress: { isPressed = true }, onRelease: { isPressed = false })
        .disabled(appState.textChunks.isEmpty)
    }
}

// MARK: - Control Button

struct ControlButton: View {
    let icon: String
    let size: CGFloat
    let action: () -> Void
    var disabled: Bool = false
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(
                        isHovered && !disabled ?
                        Color.white.opacity(0.1) :
                        Color.white.opacity(0.05)
                    )
                    .frame(width: 52, height: 52)
                    .overlay(
                        Circle()
                            .stroke(
                                isHovered && !disabled ?
                                Color(red: 0.36, green: 0.67, blue: 1.0).opacity(0.3) :
                                Color.clear,
                                lineWidth: 1
                            )
                    )
                
                Image(systemName: icon)
                    .font(.system(size: size, weight: .bold))
                    .foregroundColor(
                        disabled ? Color(white: 0.3) :
                        (isHovered ? .white : Color(white: 0.6))
                    )
            }
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .onHover { isHovered = $0 }
        .scaleEffect(isHovered && !disabled ? 1.08 : 1.0)
        .animation(.spring(response: 0.2), value: isHovered)
    }
}

// MARK: - Speed Control

struct SpeedControl: View {
    @EnvironmentObject var appState: AppState
    @State private var isExpanded = false
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 14) {
            // Speed display pill
            Button(action: { isExpanded.toggle() }) {
                HStack(spacing: 10) {
                    Image(systemName: "gauge.with.needle.fill")
                        .font(.system(size: 14, weight: .medium))
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
                    
                    Text("\(appState.playbackSpeed, specifier: "%.1f")×")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(isHovered ? 0.12 : 0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.36, green: 0.67, blue: 1.0).opacity(0.3),
                                            Color(red: 0.69, green: 0.46, blue: 1.0).opacity(0.2)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                )
            }
            .buttonStyle(.plain)
            .onHover { isHovered = $0 }
            .popover(isPresented: $isExpanded) {
                SpeedPickerPopover()
            }
            
            // Quick adjust
            HStack(spacing: 6) {
                MiniButton(icon: "minus") { appState.decreaseSpeed() }
                MiniButton(icon: "plus") { appState.increaseSpeed() }
            }
        }
    }
}

// MARK: - Mini Button

struct MiniButton: View {
    let icon: String
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(isHovered ? .white : Color(white: 0.5))
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(isHovered ? 0.12 : 0.05))
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .scaleEffect(isHovered ? 1.1 : 1.0)
        .animation(.spring(response: 0.2), value: isHovered)
    }
}

// MARK: - Speed Picker Popover

struct SpeedPickerPopover: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 8) {
            Text("SPEED")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Color(white: 0.5))
                .tracking(2)
                .padding(.bottom, 8)
            
            ForEach(AppState.speedPresets, id: \.self) { speed in
                Button(action: {
                    withAnimation(.spring(response: 0.2)) {
                        appState.playbackSpeed = speed
                        appState.saveState()
                    }
                }) {
                    HStack {
                        Text("\(speed, specifier: "%.1f")×")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(
                                appState.playbackSpeed == speed ?
                                Color(red: 0.36, green: 0.67, blue: 1.0) : .white
                            )
                        
                        Spacer()
                        
                        if appState.playbackSpeed == speed {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
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
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                appState.playbackSpeed == speed ?
                                Color(red: 0.36, green: 0.67, blue: 1.0).opacity(0.15) :
                                Color.clear
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(width: 160)
        .background(Color(red: 0.12, green: 0.14, blue: 0.19))
    }
}

// MARK: - Press Events

struct PressEventsModifier: ViewModifier {
    var onPress: () -> Void
    var onRelease: () -> Void
    
    func body(content: Content) -> some View {
        content.simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in onPress() }
                .onEnded { _ in onRelease() }
        )
    }
}

extension View {
    func pressEvents(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        modifier(PressEventsModifier(onPress: onPress, onRelease: onRelease))
    }
}

#Preview {
    PlaybackControlBar()
        .environmentObject(AppState())
        .frame(width: 900)
}
