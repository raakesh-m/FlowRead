// PiperDependencyManager.swift
// FlowRead - Automatically installs Piper TTS dependencies seamlessly
// Includes automatic Python installation if not present

import Foundation

/// Status of Piper TTS dependencies
enum PiperSetupStatus: Equatable {
    case notChecked
    case checking
    case pythonNotFound
    case installingPython
    case installing(step: String)
    case ready
    case failed(error: String)
    
    var isReady: Bool { self == .ready }
    var isWorking: Bool {
        switch self {
        case .checking, .installing, .installingPython: return true
        default: return false
        }
    }
}

/// Manages Piper TTS Python dependencies automatically
/// Handles detection and installation of Python + piper-tts package
@MainActor
class PiperDependencyManager: ObservableObject {
    
    // MARK: - Published State
    @Published var status: PiperSetupStatus = .notChecked
    @Published var logs: [String] = []
    
    // MARK: - Singleton
    static let shared = PiperDependencyManager()
    
    // MARK: - Python Paths (macOS locations)
    private let pythonSearchPaths = [
        "/usr/bin/python3",
        "/usr/local/bin/python3",
        "/opt/homebrew/bin/python3",
        "/Library/Frameworks/Python.framework/Versions/Current/bin/python3",
        "/Library/Frameworks/Python.framework/Versions/3.11/bin/python3",
        "/Library/Frameworks/Python.framework/Versions/3.12/bin/python3",
        "/Library/Frameworks/Python.framework/Versions/3.13/bin/python3"
    ]
    
    private var detectedPythonPath: String?
    
    // MARK: - Python Download Info
    // Official Python.org installer for macOS (Universal2 - works on Intel & Apple Silicon)
    private let pythonInstallerURL = "https://www.python.org/ftp/python/3.12.2/python-3.12.2-macos11.pkg"
    private let pythonInstallerName = "python-3.12.2-macos11.pkg"
    
    // MARK: - Storage Info
    static let estimatedTotalSize: String = "~150 MB"
    static let estimatedDependencySize: String = "~20 MB"
    static let estimatedModelSize: String = "~126 MB"
    
    // MARK: - Initialization
    private init() {}
    
    // MARK: - Public API
    
    /// Check if everything is ready (Python + piper-tts installed)
    func checkIfReady() async -> Bool {
        status = .checking
        logs.removeAll()
        
        log("🔍 Checking Piper TTS setup...")
        
        // Find Python
        guard let pythonPath = findPython() else {
            status = .pythonNotFound
            log("⚠️ Python 3 not found on this Mac")
            return false
        }
        detectedPythonPath = pythonPath
        log("✅ Python found: \(pythonPath)")
        
        // Check if piper-tts is installed
        let piperInstalled = await checkPiperPackage(python: pythonPath)
        
        if piperInstalled {
            status = .ready
            log("✅ piper-tts is ready!")
            return true
        } else {
            log("⚠️ piper-tts not installed yet")
            return false
        }
    }
    
    /// Install Python if not present
    func installPython() async -> Bool {
        status = .installingPython
        log("📥 Downloading Python 3.12...")
        log("   This may take a few minutes...")
        
        // Get temp directory for download
        let tempDir = FileManager.default.temporaryDirectory
        let pkgPath = tempDir.appendingPathComponent(pythonInstallerName)
        
        do {
            // Download Python installer
            guard let url = URL(string: pythonInstallerURL) else {
                log("❌ Invalid Python download URL")
                return false
            }
            
            let (downloadedURL, response) = try await URLSession.shared.download(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                log("❌ Failed to download Python installer")
                return false
            }
            
            // Move to our temp path
            try? FileManager.default.removeItem(at: pkgPath)
            try FileManager.default.moveItem(at: downloadedURL, to: pkgPath)
            
            log("✅ Python installer downloaded")
            log("📦 Installing Python (you may see a system prompt)...")
            
            // Run the installer with sudo (this will prompt the user)
            let success = await runPythonInstaller(pkgPath: pkgPath.path)
            
            // Clean up
            try? FileManager.default.removeItem(at: pkgPath)
            
            if success {
                log("✅ Python 3.12 installed successfully!")
                // Update python path
                detectedPythonPath = findPython()
                return true
            } else {
                log("❌ Python installation failed")
                return false
            }
            
        } catch {
            log("❌ Error: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Install piper-tts package automatically
    func installDependencies() async -> Bool {
        guard let pythonPath = detectedPythonPath ?? findPython() else {
            status = .pythonNotFound
            log("❌ Cannot install: Python not found")
            return false
        }
        detectedPythonPath = pythonPath
        
        status = .installing(step: "Installing piper-tts...")
        log("📦 Installing piper-tts package...")
        log("   This may take a moment...")
        
        // Install using pip
        let success = await runPipInstall(python: pythonPath, package: "piper-tts")
        
        if success {
            // Verify installation
            let verified = await checkPiperPackage(python: pythonPath)
            if verified {
                status = .ready
                log("✅ Installation complete!")
                return true
            }
        }
        
        status = .failed(error: "Installation failed")
        log("❌ Installation failed. Please try again.")
        return false
    }
    
    /// One-click setup: Check and install everything if needed
    func ensureReady() async -> Bool {
        // First check if already ready
        if await checkIfReady() {
            return true
        }
        
        // If Python not found, try to install it
        if status == .pythonNotFound {
            log("🔧 Python not found, will attempt to install...")
            let pythonInstalled = await installPython()
            
            if !pythonInstalled {
                status = .failed(error: "Could not install Python")
                return false
            }
        }
        
        // Now install piper-tts
        return await installDependencies()
    }
    
    // MARK: - Private Methods
    
    private func findPython() -> String? {
        let fm = FileManager.default
        
        for path in pythonSearchPaths {
            if fm.isExecutableFile(atPath: path) {
                return path
            }
        }
        
        // Try 'which' command
        if let path = runWhich("python3"), !path.isEmpty {
            return path
        }
        
        return nil
    }
    
    private func runWhich(_ command: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [command]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } catch {}
        
        return nil
    }
    
    private func checkPiperPackage(python: String) async -> Bool {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: python)
                process.arguments = ["-c", "from piper import PiperVoice; print('OK')"]
                
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = FileHandle.nullDevice
                
                do {
                    try process.run()
                    process.waitUntilExit()
                    
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? ""
                    continuation.resume(returning: output.contains("OK"))
                } catch {
                    continuation.resume(returning: false)
                }
            }
        }
    }
    
    private func runPipInstall(python: String, package: String) async -> Bool {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: python)
                process.arguments = ["-m", "pip", "install", "--user", "--quiet", package]
                
                // Set up environment with proper PATH
                var env = ProcessInfo.processInfo.environment
                env["PATH"] = "/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin:" + (env["PATH"] ?? "")
                process.environment = env
                
                let errorPipe = Pipe()
                process.standardOutput = FileHandle.nullDevice
                process.standardError = errorPipe
                
                do {
                    try process.run()
                    process.waitUntilExit()
                    
                    if process.terminationStatus != 0 {
                        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                        let errorStr = String(data: errorData, encoding: .utf8) ?? ""
                        Task { @MainActor in
                            self.log("⚠️ \(errorStr.prefix(200))")
                        }
                    }
                    
                    continuation.resume(returning: process.terminationStatus == 0)
                } catch {
                    Task { @MainActor in
                        self.log("❌ Error: \(error.localizedDescription)")
                    }
                    continuation.resume(returning: false)
                }
            }
        }
    }
    
    private func runPythonInstaller(pkgPath: String) async -> Bool {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                // Use 'installer' command which doesn't require sudo for user-level install
                // But for system-wide Python we need the GUI installer approach
                
                // Option 1: Try open command to launch GUI installer (user-friendly)
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                process.arguments = ["-W", pkgPath] // -W waits for app to close
                
                do {
                    try process.run()
                    process.waitUntilExit()
                    
                    // After installer closes, check if Python is now available
                    // Give it a moment to complete
                    Thread.sleep(forTimeInterval: 2.0)
                    
                    // Check if Python was installed
                    let fm = FileManager.default
                    let pythonPaths = [
                        "/Library/Frameworks/Python.framework/Versions/3.12/bin/python3",
                        "/usr/local/bin/python3"
                    ]
                    
                    let installed = pythonPaths.contains { fm.isExecutableFile(atPath: $0) }
                    continuation.resume(returning: installed)
                    
                } catch {
                    Task { @MainActor in
                        self.log("❌ Failed to run installer: \(error.localizedDescription)")
                    }
                    continuation.resume(returning: false)
                }
            }
        }
    }
    
    private func log(_ message: String) {
        logs.append(message)
        print("[PiperSetup] \(message)")
    }
}
