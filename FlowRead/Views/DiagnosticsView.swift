// DiagnosticsView.swift
// FlowRead - System diagnostics and debugging view

import SwiftUI

struct DiagnosticsView: View {
    @EnvironmentObject var appState: AppState
    @State private var diagnosticInfo: String = "Loading..."

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("System Diagnostics")
                    .font(.title)
                    .bold()

                Spacer()

                Button("Close") {
                    // Close window
                }
            }
            .padding()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    DiagnosticSection(title: "System Info") {
                        DiagnosticRow(label: "macOS Version", value: ProcessInfo.processInfo.operatingSystemVersionString)
                        DiagnosticRow(label: "App Version", value: "1.0.0")
                        DiagnosticRow(label: "Architecture", value: getArchitecture())
                    }

                    DiagnosticSection(title: "TTS Engines") {
                        DiagnosticRow(label: "Current Engine", value: appState.selectedTTSEngine.displayName)
                        DiagnosticRow(label: "Native TTS", value: "✓ Ready")
                        DiagnosticRow(label: "Groq API", value: "✓ Ready")
                        DiagnosticRow(
                            label: "Kokoro TTS",
                            value: appState.ttsManager.isEngineReady() && appState.selectedTTSEngine == .kokoro ? "✓ Ready" : "⚠ Models Required"
                        )
                        DiagnosticRow(
                            label: "Piper TTS",
                            value: appState.ttsManager.isEngineReady() && appState.selectedTTSEngine == .piper ? "✓ Ready" : "⚠ Models Required"
                        )
                    }

                    DiagnosticSection(title: "Model Status") {
                        DiagnosticRow(label: "Kokoro Model", value: modelStatus(for: .kokoro))
                        DiagnosticRow(label: "Piper Models", value: modelStatus(for: .piper))
                    }

                    DiagnosticSection(title: "Paths") {
                        DiagnosticRow(label: "Log File", value: Logger.shared.getLogPath())
                        DiagnosticRow(label: "Models Directory", value: ModelDownloadManager.modelsDirectory.path)
                        DiagnosticRow(label: "App Support", value: appState.persistenceManager.stateFileURL.path)
                    }

                    DiagnosticSection(title: "Current State") {
                        DiagnosticRow(label: "PDF Loaded", value: appState.pdfDocument != nil ? "Yes" : "No")
                        DiagnosticRow(label: "Text Chunks", value: "\(appState.textChunks.count)")
                        DiagnosticRow(label: "Current Chunk", value: "\(appState.currentChunkIndex)")
                        DiagnosticRow(label: "Is Playing", value: appState.isPlaying ? "Yes" : "No")
                        DiagnosticRow(label: "Playback Speed", value: String(format: "%.2fx", appState.playbackSpeed))
                    }
                }
                .padding()
            }

            HStack {
                Button("Open Logs Folder") {
                    let logURL = URL(fileURLWithPath: Logger.shared.getLogPath())
                    NSWorkspace.shared.open(logURL.deletingLastPathComponent())
                }

                Button("Copy Diagnostics") {
                    copyDiagnostics()
                }

                Spacer()
            }
            .padding()
        }
        .frame(minWidth: 600, minHeight: 500)
    }

    private func getArchitecture() -> String {
        #if arch(arm64)
        return "Apple Silicon (ARM64)"
        #elseif arch(x86_64)
        return "Intel (x86_64)"
        #else
        return "Unknown"
        #endif
    }

    private func modelStatus(for engine: TTSEngine) -> String {
        let fm = FileManager.default
        switch engine {
        case .kokoro:
            let modelExists = fm.fileExists(atPath: ModelDownloadManager.kokoroModelPath.path)
            let tokenizerExists = fm.fileExists(atPath: ModelDownloadManager.kokoroTokenizerPath.path)
            if modelExists && tokenizerExists {
                return "✓ Downloaded"
            } else {
                return "✗ Not Downloaded"
            }
        case .piper:
            let amy = fm.fileExists(atPath: ModelDownloadManager.piperModelPath(for: .amy_medium).path)
            let ryan = fm.fileExists(atPath: ModelDownloadManager.piperModelPath(for: .ryan_medium).path)
            if amy && ryan {
                return "✓ Both Downloaded"
            } else if amy || ryan {
                return "⚠ Partial Download"
            } else {
                return "✗ Not Downloaded"
            }
        default:
            return "N/A"
        }
    }

    private func copyDiagnostics() {
        let info = """
        FlowRead Diagnostics
        ====================
        macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)
        Architecture: \(getArchitecture())
        App Version: 1.0.0

        TTS Engine: \(appState.selectedTTSEngine.displayName)
        Kokoro Status: \(modelStatus(for: .kokoro))
        Piper Status: \(modelStatus(for: .piper))

        Log: \(Logger.shared.getLogPath())
        """

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(info, forType: .string)
    }
}

struct DiagnosticSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .padding(.bottom, 4)

            content
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

struct DiagnosticRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label + ":")
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
        }
    }
}
