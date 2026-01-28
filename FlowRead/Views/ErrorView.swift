// ErrorView.swift
// FlowRead - Error display view

import SwiftUI

struct ErrorView: View {
    let error: Error
    let logPath: String

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundColor(.red)

            Text("FlowRead Failed to Start")
                .font(.title)
                .bold()

            Text(error.localizedDescription)
                .font(.body)
                .multilineTextAlignment(.center)
                .padding()

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Log File Location:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(logPath)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(8)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(4)

                Button("Open Log Folder") {
                    let url = URL(fileURLWithPath: logPath).deletingLastPathComponent()
                    NSWorkspace.shared.open(url)
                }
            }
            .padding()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(40)
        .frame(minWidth: 500, minHeight: 400)
    }
}
