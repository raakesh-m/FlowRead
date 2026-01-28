// PersistenceManager.swift
// FlowRead - Local state persistence

import Foundation

/// Manages local persistence of app state
class PersistenceManager {
    private let userDefaults = UserDefaults.standard
    private let stateKey = "com.flowread.persistedState"
    
    var stateFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupport.appendingPathComponent("FlowRead", isDirectory: true)

        // Create directory if needed
        try? FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true)

        return appDirectory.appendingPathComponent("state.json")
    }
    
    /// Save state to disk
    func saveState(_ state: PersistedState) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(state)
            try data.write(to: stateFileURL, options: .atomic)
        } catch {
            print("Failed to save state: \(error)")
            // Fallback to UserDefaults
            saveToUserDefaults(state)
        }
    }
    
    /// Load state from disk
    func loadState() -> PersistedState {
        // Try file first
        if let state = loadFromFile() {
            return state
        }
        
        // Fallback to UserDefaults
        if let state = loadFromUserDefaults() {
            return state
        }
        
        return .default
    }
    
    private func loadFromFile() -> PersistedState? {
        guard FileManager.default.fileExists(atPath: stateFileURL.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: stateFileURL)
            let decoder = JSONDecoder()
            return try decoder.decode(PersistedState.self, from: data)
        } catch {
            print("Failed to load state from file: \(error)")
            return nil
        }
    }
    
    private func saveToUserDefaults(_ state: PersistedState) {
        do {
            let data = try JSONEncoder().encode(state)
            userDefaults.set(data, forKey: stateKey)
        } catch {
            print("Failed to save to UserDefaults: \(error)")
        }
    }
    
    private func loadFromUserDefaults() -> PersistedState? {
        guard let data = userDefaults.data(forKey: stateKey) else {
            return nil
        }
        
        do {
            return try JSONDecoder().decode(PersistedState.self, from: data)
        } catch {
            print("Failed to load from UserDefaults: \(error)")
            return nil
        }
    }
    
    /// Clear all persisted state
    func clearState() {
        try? FileManager.default.removeItem(at: stateFileURL)
        userDefaults.removeObject(forKey: stateKey)
    }
    
    /// Get the app support directory path
    var appSupportPath: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("FlowRead", isDirectory: true)
    }
}
