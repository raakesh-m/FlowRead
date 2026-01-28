// Logger.swift
// FlowRead - File-based logging system for debugging

import Foundation

/// Centralized logging system that writes to file
class Logger {
    static let shared = Logger()

    private let logFileURL: URL
    private let queue = DispatchQueue(label: "com.flowread.logger", qos: .utility)
    private var fileHandle: FileHandle?

    private init() {
        // Create logs directory
        let logsDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("FlowRead")
            .appendingPathComponent("Logs")

        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)

        // Create log file with timestamp
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())

        logFileURL = logsDir.appendingPathComponent("flowread_\(timestamp).log")

        // Create file if it doesn't exist
        if !FileManager.default.fileExists(atPath: logFileURL.path) {
            FileManager.default.createFile(atPath: logFileURL.path, contents: nil)
        }

        // Open file handle
        fileHandle = try? FileHandle(forWritingTo: logFileURL)
        fileHandle?.seekToEndOfFile()

        // Log startup
        log("=== FlowRead Started ===", level: .info)
        log("Log file: \(logFileURL.path)", level: .info)
        log("macOS version: \(ProcessInfo.processInfo.operatingSystemVersionString)", level: .info)
        log("App version: 1.0.0", level: .info)
    }

    enum LogLevel: String {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
        case critical = "CRITICAL"
    }

    func log(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let filename = (file as NSString).lastPathComponent
        let logMessage = "[\(timestamp)] [\(level.rawValue)] [\(filename):\(line)] \(function) - \(message)\n"

        // Print to console
        print(logMessage, terminator: "")

        // Write to file
        queue.async { [weak self] in
            guard let self = self,
                  let data = logMessage.data(using: .utf8) else { return }
            self.fileHandle?.write(data)
        }
    }

    func logError(_ error: Error, context: String = "", file: String = #file, function: String = #function, line: Int = #line) {
        let message = context.isEmpty ? error.localizedDescription : "\(context): \(error.localizedDescription)"
        log(message, level: .error, file: file, function: function, line: line)
    }

    func getLogPath() -> String {
        return logFileURL.path
    }

    deinit {
        log("=== FlowRead Shutdown ===", level: .info)
        try? fileHandle?.close()
    }
}

// Convenience global functions
func logDebug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.log(message, level: .debug, file: file, function: function, line: line)
}

func logInfo(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.log(message, level: .info, file: file, function: function, line: line)
}

func logWarning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.log(message, level: .warning, file: file, function: function, line: line)
}

func logError(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.log(message, level: .error, file: file, function: function, line: line)
}

func logCritical(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.log(message, level: .critical, file: file, function: function, line: line)
}
