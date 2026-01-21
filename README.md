# FlowRead

<p align="center">
  <img src="docs/logo.png" alt="FlowRead Logo" width="128" height="128">
</p>

<h3 align="center">Read. Listen. Flow.</h3>

<p align="center">
  A native macOS PDF reader with intelligent Text-to-Speech, synchronized highlighting, and auto-scroll.
</p>

---

## ✨ Features

- **📖 Native PDF Reading** - Load and read PDFs with a clean, distraction-free interface
- **🎧 Text-to-Speech** - Listen to your documents using Groq's high-quality TTS API
- **✨ Synchronized Highlighting** - See exactly which sentence is being read
- **📜 Auto-Scroll** - The view automatically follows along with the audio
- **⚡ Lightweight & Fast** - Native Swift/SwiftUI for minimal resource usage
- **🔐 Privacy-First** - No analytics, no telemetry, all data stays local

## 📋 Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15.0+ (for building from source)
- Groq API key(s) for Text-to-Speech functionality

## 🚀 Quick Start

### Installation (from DMG)

1. Download the latest `FlowRead.dmg` from [Releases](../../releases)
2. Open the DMG file
3. Drag FlowRead to your Applications folder
4. Open FlowRead
5. Configure your Groq API keys in Preferences (⌘,)

### Building from Source

```bash
# Clone the repository
git clone https://github.com/yourusername/FlowRead.git
cd FlowRead

# Build and create DMG
chmod +x build.sh
./build.sh

# Or for quick debug build
chmod +x run-debug.sh
./run-debug.sh
```

## 🔑 API Key Configuration

FlowRead requires Groq API keys for Text-to-Speech. You can configure up to 5 keys for automatic load balancing and failover.

### Option 1: Environment Variables

```bash
export GROQ_API_KEY="your_key_here"
# Or for multiple keys:
export GROQ_API_KEY_1="key_1"
export GROQ_API_KEY_2="key_2"
export GROQ_API_KEY_3="key_3"
```

### Option 2: Config File

Create `~/.flowread/api_keys.json`:

```json
{
  "groq_api_keys": [
    "gsk_your_first_key",
    "gsk_your_second_key",
    "gsk_your_third_key"
  ]
}
```

### Option 3: In-App Preferences

Open Preferences (⌘,) → API Keys tab → Enter your keys

## ⌨️ Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| Open PDF | ⌘O |
| Play/Pause | Space |
| Next Sentence | ⌘→ |
| Previous Sentence | ⌘← |
| Increase Speed | ⌘+ |
| Decrease Speed | ⌘- |
| Preferences | ⌘, |

## 📁 Project Structure

```
FlowRead/
├── FlowRead.xcodeproj/     # Xcode project
├── FlowRead/
│   ├── FlowReadApp.swift   # App entry point
│   ├── Models/
│   │   ├── AppState.swift  # Central state management
│   │   ├── TextChunk.swift # Text chunk model
│   │   └── PersistedState.swift
│   ├── Services/
│   │   ├── GroqTTSService.swift      # TTS API integration
│   │   ├── AudioPlaybackManager.swift # Audio playback
│   │   ├── PDFTextProcessor.swift    # PDF text extraction
│   │   └── PersistenceManager.swift  # Local storage
│   ├── Views/
│   │   ├── ContentView.swift         # Main view
│   │   ├── MainReadingView.swift     # Reading interface
│   │   ├── ReadingPane.swift         # Text display
│   │   ├── PlaybackControlBar.swift  # Playback controls
│   │   └── PreferencesView.swift     # Settings
│   ├── Theme/
│   │   └── Theme.swift              # Color definitions
│   └── Assets.xcassets/             # Colors & icons
├── build.sh                # Release build script
├── run-debug.sh           # Debug build script
└── README.md
```

## 🎨 Design Principles

- **Reliability over feature count** - Core features work flawlessly
- **Simplicity over complexity** - Clean, focused interface
- **Native performance** - No Electron, no web views
- **Privacy first** - Your data stays on your device

## 🔧 Development

### Prerequisites

- Xcode 15.0+
- macOS 13.0+
- Swift 5.9+

### Running in Development

```bash
# Open in Xcode
open FlowRead.xcodeproj

# Or build from command line
./run-debug.sh
```

### Creating a Release

```bash
./build.sh
```

This will:
1. Build the Release configuration
2. Create an app bundle
3. Generate a DMG installer in `build/FlowRead.dmg`

## 📝 How It Works

1. **PDF Loading**: Uses PDFKit to load and render PDF documents
2. **Text Extraction**: Extracts text using PDFKit with NaturalLanguage framework for intelligent sentence splitting
3. **TTS Synthesis**: Sends text chunks to Groq API, receives audio data
4. **Audio Playback**: Uses AVFoundation for native audio playback with speed control
5. **Synchronization**: Tracks current chunk index to sync highlighting and auto-scroll
6. **Persistence**: Saves state to Application Support directory

## 🛡️ Security & Privacy

- **No telemetry or analytics** - Zero data collection
- **No cloud storage** - All data stored locally
- **Minimal network usage** - Only Groq TTS API calls
- **API keys secured** - Never logged or transmitted elsewhere
- **Sandboxed** - macOS app sandbox for security

## 📄 License

MIT License - See [LICENSE](LICENSE) for details.

## 🙏 Acknowledgments

- [Groq](https://groq.com) for their excellent TTS API
- Apple's PDFKit and AVFoundation frameworks
- The Swift and SwiftUI communities

---

<p align="center">
  Made with ❤️ for readers who love to listen
</p>
