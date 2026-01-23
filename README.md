# FlowRead

<p align="center">
  <img src="docs/logo.png" alt="FlowRead Logo" width="128" height="128">
</p>

<h3 align="center">Read • Listen • Flow</h3>

<p align="center">
  A native macOS PDF reader with intelligent Text-to-Speech, synchronized highlighting, smart auto-scroll, and comprehensive keyboard controls.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-13.0+-blue?logo=apple" alt="macOS 13.0+">
  <img src="https://img.shields.io/badge/Swift-5.9-orange?logo=swift" alt="Swift 5.9">
  <img src="https://img.shields.io/badge/SwiftUI-Native-green" alt="SwiftUI">
  <img src="https://img.shields.io/badge/License-MIT-yellow" alt="MIT License">
</p>

---

## ✨ Features

### Core Functionality
- **📖 Native PDF Reading** — Load and read PDFs with a clean, distraction-free interface
- **🎧 Text-to-Speech** — Listen to documents using Groq's Orpheus TTS with 6 professional voices
- **✨ Synchronized Highlighting** — See exactly which sentence is being read in real-time
- **📜 Smart Auto-Scroll** — View intelligently follows along, pauses when you scroll manually, and resumes on the next sentence

### Audio & Playback
- **🎚️ Variable Speed** — Adjust playback from 0.5x to 2.0x
- **🎤 Voice Selection** — Choose from 6 distinct voices (Autumn, Diana, Hannah, Austin, Daniel, Troy)
- **⏯️ Full Playback Control** — Play, pause, stop, skip forward/backward
- **🔊 TTS Toggle** — Switch between audio+visual or visual-only mode

### Smart Features
- **🔤 Roman Numeral Detection** — Automatically converts standalone chapter markers (I, II, III) to spoken "Chapter 1, Chapter 2, Chapter 3"
- **💾 Session Persistence** — Remembers your last PDF, exact reading position, speed, voice, and settings across app launches
- **🔐 Security-Scoped Bookmarks** — Maintains file access even with macOS sandboxing

### User Experience
- **⌨️ Comprehensive Keyboard Shortcuts** — Control everything without touching the mouse
- **📐 Responsive Design** — Adapts beautifully to any window size
- **🎨 Modern Dark UI** — Vibrant gradients and smooth animations
- **⚡ Lightweight & Fast** — Native Swift/SwiftUI for minimal resource usage
- **🔐 Privacy-First** — No analytics, no telemetry, all data stays local

---

## 📋 Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15.0+ (for building from source)
- Groq API key(s) for Text-to-Speech functionality

---

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
git clone https://github.com/raakesh-m/FlowRead.git
cd FlowRead

# Build and create DMG
chmod +x build.sh
./build.sh

# Or for quick debug build
chmod +x run-debug.sh
./run-debug.sh
```

---

## 🔑 API Key Configuration

FlowRead requires Groq API keys for Text-to-Speech. You can configure up to 5 keys for automatic load balancing and failover.

### Option 1: Environment Variables

```bash
export GROQ_API_KEY="your_key_here"
# Or for multiple keys (recommended for rate limit handling):
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

---

## ⌨️ Keyboard Shortcuts

FlowRead features comprehensive keyboard controls inspired by media players like VLC and YouTube.

### File Operations
| Shortcut | Action |
|----------|--------|
| `⌘O` | Open PDF |
| `⌘,` | Open Preferences |

### Playback
| Shortcut | Action |
|----------|--------|
| `Space` | Play / Pause |
| `Esc` | Stop playback |
| `←` | Previous sentence |
| `→` | Next sentence |
| `⌘↑` | Jump to beginning |
| `⌘↓` | Jump to end |

### Speed Control
| Shortcut | Action |
|----------|--------|
| `↑` | Increase speed |
| `↓` | Decrease speed |
| `R` | Reset speed to 1.0x |

### View & Features
| Shortcut | Action |
|----------|--------|
| `A` | Toggle auto-scroll |
| `T` | Toggle TTS on/off |
| `⌘=` | Increase font size |
| `⌘-` | Decrease font size |
| `⌘0` | Reset font size |

---

## 🎤 Available Voices

FlowRead uses Groq's Orpheus TTS model with 6 professionally-trained voices:

| Voice | Gender | Description |
|-------|--------|-------------|
| **Autumn** | Female | Warm & natural |
| **Diana** | Female | Clear & professional |
| **Hannah** | Female | Calm & soothing |
| **Austin** | Male | Deep & confident |
| **Daniel** | Male | Friendly & expressive |
| **Troy** | Male | Strong & articulate |

---

## 📁 Project Structure

```
FlowRead/
├── FlowRead.xcodeproj/          # Xcode project
├── FlowRead/
│   ├── FlowReadApp.swift        # App entry point & menu commands
│   ├── Models/
│   │   ├── AppState.swift       # Central state management
│   │   ├── TextChunk.swift      # Text chunk model
│   │   └── PersistedState.swift # Session persistence model
│   ├── Services/
│   │   ├── GroqTTSService.swift      # TTS API with key rotation
│   │   ├── AudioPlaybackManager.swift # AVFoundation audio
│   │   ├── PDFTextProcessor.swift    # Smart text extraction
│   │   └── PersistenceManager.swift  # Local storage
│   ├── Views/
│   │   ├── ContentView.swift         # Main container
│   │   ├── MainReadingView.swift     # Reading interface
│   │   ├── ReadingPane.swift         # Smart auto-scrolling text
│   │   ├── PlaybackControlBar.swift  # Control center
│   │   └── PreferencesView.swift     # Settings tabs
│   └── Assets.xcassets/              # Colors & icons
├── docs/
│   └── ARCHITECTURE.md          # Technical documentation
├── build.sh                     # Release build script
├── run-debug.sh                 # Debug build script
└── README.md
```

---

## 🎨 Design Principles

- **Reliability over feature count** — Core features work flawlessly
- **Simplicity over complexity** — Clean, focused interface
- **Native performance** — No Electron, no web views, pure Swift
- **Privacy first** — Your data stays on your device
- **Keyboard-first** — Everything accessible without a mouse

---

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

---

## 📝 How It Works

### 1. PDF Loading & Text Extraction
- Uses **PDFKit** to load PDF documents
- **NaturalLanguage framework** for intelligent sentence splitting
- **Smart chapter detection** — Recognizes Roman numerals (I, II, III) as chapter markers and converts them to spoken form

### 2. Text-to-Speech
- Sends text chunks to **Groq's Orpheus API**
- **Round-robin key rotation** with automatic failover
- **Audio caching** — Pre-fetches upcoming sentences for seamless playback

### 3. Audio Playback
- **AVFoundation** for native audio with variable speed (0.5x - 2.0x)
- Tracks chunk completion for synchronized progression

### 4. Smart Auto-Scroll
- Positions current sentence in the **upper 25%** of the screen for comfortable reading
- **Pauses on manual scroll** — Shows a badge indicating pause status
- **Auto-resumes** on next sentence change

### 5. Session Persistence
- **Security-scoped bookmarks** — Maintains PDF file access across launches
- Saves reading position, speed, voice, font size, and all preferences
- Automatically restores your last session on app launch

---

## 🛡️ Security & Privacy

- **No telemetry or analytics** — Zero data collection
- **No cloud storage** — All data stored locally in Application Support
- **Minimal network usage** — Only Groq TTS API calls
- **API keys secured** — Stored locally, never logged or transmitted
- **Sandboxed** — Full macOS app sandbox for security
- **Security-scoped bookmarks** — Secure file access that persists across launches

---

## 📄 License

MIT License — See [LICENSE](LICENSE) for details.

---

## 🙏 Acknowledgments

- [Groq](https://groq.com) for their excellent Orpheus TTS API
- Apple's PDFKit, AVFoundation, and NaturalLanguage frameworks
- The Swift and SwiftUI communities

---

<p align="center">
  Made with ❤️ for readers who love to listen
</p>

<p align="center">
  <a href="https://github.com/raakesh-m/FlowRead">⭐ Star this repo if you find it useful!</a>
</p>
