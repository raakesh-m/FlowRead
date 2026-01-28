// TTSErrorBanner.swift
// FlowRead - Banner to display TTS errors

import SwiftUI

struct TTSErrorBanner: View {
    let error: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.system(size: 18))

            VStack(alignment: .leading, spacing: 4) {
                Text("TTS Engine Fallback")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)

                Text(error)
                    .font(.system(size: 12))
                    .foregroundColor(Color.white.opacity(0.9))
                    .lineLimit(2)
            }

            Spacer()

            Button(action: {
                // Open logs
                let logPath = Logger.shared.getLogPath()
                let logURL = URL(fileURLWithPath: logPath).deletingLastPathComponent()
                NSWorkspace.shared.open(logURL)
            }) {
                Text("View Logs")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Color.orange.opacity(0.2)
                .background(.ultraThinMaterial)
        )
        .overlay(
            Rectangle()
                .fill(Color.orange.opacity(0.6))
                .frame(height: 2),
            alignment: .bottom
        )
    }
}
