# FlowRead Architecture

This document describes the architecture and design of FlowRead.

## Overview

FlowRead is a native macOS application built with Swift and SwiftUI. It follows a clean architecture pattern with clear separation of concerns.

```
┌─────────────────────────────────────────────────────────────┐
│                        FlowRead App                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                    Views (SwiftUI)                   │   │
│  │  ContentView → MainReadingView → ReadingPane        │   │
│  │                     ↓                                │   │
│  │              PlaybackControlBar                      │   │
│  │              PreferencesView                         │   │
│  └─────────────────────────────────────────────────────┘   │
│                           ↓                                 │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                  AppState (ObservableObject)         │   │
│  │  - Manages all application state                     │   │
│  │  - Coordinates between services                      │   │
│  │  - Published properties for reactive UI              │   │
│  └─────────────────────────────────────────────────────┘   │
│                           ↓                                 │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                      Services                        │   │
│  │  ┌──────────────┐  ┌──────────────┐                 │   │
│  │  │ PDFProcessor │  │ GroqTTSServ  │                 │   │
│  │  └──────────────┘  └──────────────┘                 │   │
│  │  ┌──────────────┐  ┌──────────────┐                 │   │
│  │  │ AudioManager │  │ Persistence  │                 │   │
│  │  └──────────────┘  └──────────────┘                 │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Components

### Models

#### `AppState`
Central state manager using `@MainActor` for thread-safe UI updates.

```swift
@MainActor
class AppState: ObservableObject {
    @Published var pdfDocument: PDFDocument?
    @Published var textChunks: [TextChunk] = []
    @Published var currentChunkIndex: Int = 0
    @Published var isPlaying: Bool = false
    // ... more state
}
```

Key responsibilities:
- Manages all application state
- Coordinates between services
- Handles playback logic
- Persists state between sessions

#### `TextChunk`
Represents a unit of text for TTS processing.

```swift
struct TextChunk: Identifiable, Equatable {
    let id: UUID
    let text: String
    let pageIndex: Int
    let range: NSRange
    let boundingRect: CGRect?
}
```

### Services

#### `GroqTTSService`
Handles all Groq API communication as an `actor` for thread safety.

```swift
actor GroqTTSService {
    private var apiKeys: [String] = []
    private var currentKeyIndex: Int = 0
    private var failedKeys: Set<Int> = []
    
    func synthesize(text: String) async throws -> Data
}
```

Features:
- Round-robin key rotation
- Automatic failover on rate limits
- Configurable voice selection
- Keys from env vars or config file

#### `AudioPlaybackManager`
Native audio playback using AVFoundation.

```swift
@MainActor
class AudioPlaybackManager: NSObject, ObservableObject {
    @Published var isPlaying: Bool = false
    @Published var currentChunkCompleted: Bool = false
    @Published var playbackProgress: Double = 0.0
    
    func play(audioData: Data) async
    func pause()
    func setPlaybackSpeed(_ speed: Double)
}
```

Features:
- Variable speed playback
- Progress tracking
- Delegate callbacks for completion

#### `PDFTextProcessor`
Extracts and processes text from PDFs.

```swift
class PDFTextProcessor {
    enum ChunkMode { case sentence, paragraph }
    
    func extractTextChunks(from document: PDFDocument) async throws -> [TextChunk]
}
```

Features:
- NaturalLanguage framework for sentence detection
- Smart chunking for TTS (max ~200 chars)
- Handles edge cases (headers, footers, etc.)

#### `PersistenceManager`
Local state persistence.

```swift
class PersistenceManager {
    func saveState(_ state: PersistedState)
    func loadState() -> PersistedState
}
```

Storage:
- Primary: JSON file in Application Support
- Fallback: UserDefaults

### Views

#### View Hierarchy

```
ContentView
├── WelcomeView (when no PDF loaded)
│   └── Open PDF button
└── MainReadingView (when PDF loaded)
    ├── TopToolbar
    │   ├── Document info
    │   ├── ProgressIndicator
    │   └── Toolbar buttons
    ├── ReadingPane
    │   └── LazyVStack of TextChunkView
    └── PlaybackControlBar
        ├── CurrentChunkInfo
        ├── PlaybackControls
        └── SpeedControl
```

#### Data Flow

1. User opens PDF → `AppState.loadPDF(from:)`
2. PDF processed → `textChunks` populated
3. User presses Play → `AppState.play()`
4. TTS called → Audio data received
5. Audio plays → `currentChunkCompleted` triggers
6. Next chunk → UI updates, scroll to highlight

### Threading Model

```
Main Thread (UI)                 Background
     │                              │
     │ ←── @Published ───           │
     │                  │           │
  AppState ─────────────┼──────► PDFProcessor
     │                  │           │
     │                  │           │
     ├──────────────────┼──────► GroqTTSService (actor)
     │                  │           │
     │                  │           │
     └── AudioManager ──┘           │
         (MainActor)
```

- UI always on main thread via `@MainActor`
- Heavy work (PDF processing, network) on background threads
- `async/await` for clean concurrency
- `actor` for thread-safe service access

## Data Persistence

### Persisted State

```swift
struct PersistedState: Codable {
    var lastPDFPath: String?
    var lastReadingPosition: Int?
    var playbackSpeed: Double
    var autoScrollEnabled: Bool
    var selectedVoice: String?
}
```

### Storage Locations

- **State**: `~/Library/Application Support/FlowRead/state.json`
- **API Keys**: `~/.flowread/api_keys.json`

## Error Handling

Errors are handled at multiple levels:

1. **Service Level**: Specific error types (e.g., `GroqTTSError`)
2. **AppState Level**: Centralized error handling and user notification
3. **View Level**: Error display via alerts

```swift
enum GroqTTSError: Error {
    case noAPIKeysConfigured
    case allKeysExhausted
    case rateLimited
    case networkError(String)
    case invalidResponse
}
```

## Security

### Sandboxing
App runs in macOS sandbox with minimal permissions:
- User-selected files (PDFs)
- Network client (TTS API only)

### API Key Security
- Never logged
- Never sent except to Groq
- Stored with restricted file permissions
- Environment variables preferred

## Performance Considerations

1. **Lazy Loading**: Text chunks loaded on-demand
2. **Streaming TTS**: Audio generated per-chunk, not entire document
3. **Efficient UI**: `LazyVStack` for large documents
4. **Memory**: Audio data released after playback
5. **Background Processing**: PDF extraction off main thread

## Future Architecture Considerations

### Potential Improvements

1. **Offline TTS**: Local model integration (e.g., whisper.cpp)
2. **PDF Caching**: Pre-process and cache text extraction
3. **Audio Caching**: Cache TTS audio for repeated sentences
4. **Bookmarks**: User-defined reading positions
5. **Chapter Detection**: Smart document navigation

### Extension Points

- `TTSProvider` protocol for multiple TTS backends
- `PDFRenderer` protocol for alternative PDF libraries
- Plugin system for custom processing

---

For implementation details, see the source files in:
- `FlowRead/Models/`
- `FlowRead/Services/`
- `FlowRead/Views/`
