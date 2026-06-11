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
- **🎧 Multi-Engine Text-to-Speech** — Choose from 4 TTS engines: macOS Native, Groq API, OpenAI TTS, and Piper (local AI)
- **✨ Synchronized Highlighting** — See exactly which sentence is being read in real-time
- **📜 Smart Auto-Scroll** — View intelligently follows along, pauses when you scroll manually, and resumes on the next sentence

### Audio & Playback
- **🎚️ Variable Speed** — Adjust playback from 0.5x to 2.0x
- **🎤 Voice Selection** — Pick from each engine's voice lineup (see [TTS Engines & Voices](#-tts-engines--voices))
- **🔀 Switch Engines Anytime** — Change engines on the fly; FlowRead re-optimizes text chunking and restores your position
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
- **No API key required** to get started — the macOS Native engine works offline out of the box
- Optional, depending on the engine you choose:
  - **Groq API key(s)** for the Groq engine
  - **OpenAI API key** for the OpenAI engine
  - **Python 3** + a one-time ~126 MB model download for the Piper engine

---

## 🚀 Quick Start

### Installation (from DMG)

1. Download the latest `FlowRead.dmg` from [Releases](../../releases)
2. Open the DMG file
3. Drag FlowRead to your Applications folder
4. Open FlowRead
5. Start reading immediately with the **macOS Native** engine, or open Preferences (⌘,) to pick another TTS engine and add API keys

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

API keys are **only needed for the cloud engines** (Groq and OpenAI). The macOS Native and Piper engines run entirely on-device.

- **Groq** supports up to 5 keys for automatic load balancing and failover (handy for rate limits).
- **OpenAI** uses a single key.

Keys are loaded in this order of precedence: **environment variables → config file → in-app Preferences**.

### Option 1: Environment Variables

```bash
# Groq — single key:
export GROQ_API_KEY="gsk_your_key_here"
# Or multiple keys (recommended for rate-limit handling):
export GROQ_API_KEY_1="key_1"
export GROQ_API_KEY_2="key_2"
export GROQ_API_KEY_3="key_3"

# OpenAI:
export OPENAI_API_KEY="sk_your_key_here"
```

### Option 2: Config File

Create `~/.flowread/api_keys.json` (`~/.config/flowread/api_keys.json` also works):

```json
{
  "groq_api_keys": [
    "gsk_your_first_key",
    "gsk_your_second_key",
    "gsk_your_third_key"
  ],
  "openai_api_key": "sk_your_key_here"
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

## 🎤 TTS Engines & Voices

FlowRead ships with **4 interchangeable TTS engines**. Switch between them anytime in Preferences (⌘,) → TTS tab — FlowRead automatically re-optimizes the text chunking for the selected engine and keeps your reading position.

| Engine | Type | Cost | API Key | Download | Quality |
|--------|------|------|---------|----------|---------|
| **macOS Native** | On-device, offline | Free | — | — | Good |
| **Groq API** | Cloud (Orpheus) | Per Groq pricing | Required | — | Excellent |
| **OpenAI TTS** | Cloud | $15–30 / 1M chars | Required | — | Excellent |
| **Piper TTS** | On-device AI (local) | Free | — | ~126 MB | Very Good |

> **Default:** FlowRead starts with the **macOS Native** engine so it works immediately with no setup. If a Piper synthesis ever fails, FlowRead automatically falls back to macOS Native.

### macOS Native

Built into macOS via `NSSpeechSynthesizer` — works fully offline, zero setup.

| Voice | Gender | Accent | Notes |
|-------|--------|--------|-------|
| **Samantha** | Female | American | Clear |
| **Daniel** | Male | British | Premium |

### Groq API

Groq's **Orpheus** TTS model (`canopylabs/orpheus-v1-english`) with 6 professionally-trained voices.

| Voice | Gender | Description |
|-------|--------|-------------|
| **Autumn** | Female | Warm & natural |
| **Diana** | Female | Clear & professional |
| **Hannah** | Female | Calm & soothing |
| **Austin** | Male | Deep & confident |
| **Daniel** | Male | Friendly & expressive |
| **Troy** | Male | Strong & articulate |

### OpenAI TTS

OpenAI's cloud TTS with selectable model quality (`tts-1` standard, `tts-1-hd` high quality) and 6 voices.

| Voice | Gender | Description |
|-------|--------|-------------|
| **Alloy** | Neutral | Versatile & balanced |
| **Echo** | Male | Warm & conversational |
| **Fable** | Neutral | Expressive & dynamic |
| **Onyx** | Male | Deep & authoritative |
| **Nova** | Female | Friendly & upbeat |
| **Shimmer** | Female | Clear & optimistic |

### Piper TTS

Lightweight, fully-local neural TTS. Models run through a Python backend (keeping the app itself tiny). Requires Python 3 and a one-time model download (~63 MB per voice) pulled from the [rhasspy/piper-voices](https://huggingface.co/rhasspy/piper-voices) collection on Hugging Face.

| Voice | Gender | Model | Description |
|-------|--------|-------|-------------|
| **Amy** | Female | `en_US-amy-medium` | Clear, professional |
| **Ryan** | Male | `en_US-ryan-medium` | Warm, friendly |

---

## 📁 Project Structure

```
FlowRead/
├── FlowRead.xcodeproj/          # Xcode project
├── FlowRead/
│   ├── FlowReadApp.swift        # App entry point & menu commands
│   ├── Models/
│   │   ├── AppState.swift       # Central state management
│   │   ├── TTSEngine.swift      # TTS engine definitions & Piper voices
│   │   ├── TextChunk.swift      # Text chunk model
│   │   └── PersistedState.swift # Session persistence model
│   ├── Services/
│   │   ├── TTSManager.swift            # Unified coordinator for all engines
│   │   ├── NativeTTSService.swift      # macOS NSSpeechSynthesizer engine
│   │   ├── GroqTTSService.swift        # Groq API with key rotation
│   │   ├── OpenAITTSService.swift      # OpenAI TTS API
│   │   ├── PiperTTSService.swift       # Local Piper (Python backend)
│   │   ├── ModelDownloadManager.swift  # Piper model downloads
│   │   ├── PiperDependencyManager.swift # Piper/Python dependency checks
│   │   ├── AudioPlaybackManager.swift  # AVFoundation audio
│   │   ├── PDFTextProcessor.swift      # Smart text extraction & chunking
│   │   ├── PersistenceManager.swift    # Local storage
│   │   └── Logger.swift                # Logging
│   ├── Views/
│   │   ├── ContentView.swift         # Main container
│   │   ├── MainReadingView.swift     # Reading interface
│   │   ├── ReadingPane.swift         # Smart auto-scrolling text
│   │   ├── PlaybackControlBar.swift  # Control center
│   │   ├── PreferencesView.swift     # Settings tabs
│   │   ├── TTSPreferencesView.swift  # Engine & voice selection
│   │   ├── TTSErrorBanner.swift      # Inline TTS error display
│   │   ├── DiagnosticsView.swift     # Diagnostics
│   │   └── ErrorView.swift           # Error display
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
- A unified **`TTSManager`** routes synthesis to the selected engine:
  - **macOS Native** — `NSSpeechSynthesizer`, fully offline
  - **Groq** — Orpheus API with **round-robin key rotation** and automatic failover
  - **OpenAI** — cloud TTS with selectable `tts-1` / `tts-1-hd` models
  - **Piper** — local neural model run via a Python backend (auto-falls back to macOS Native on failure)
- **Adaptive chunking** — Text is split to respect each engine's limits (e.g. Groq's ~200-char cap, Piper's phoneme limit) while breaking at natural sentence boundaries
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
- **Offline-capable** — macOS Native and Piper engines need no network at all
- **Minimal network usage** — Cloud engines (Groq/OpenAI) only contact their own TTS endpoints
- **API keys secured** — Stored locally, never logged or transmitted
- **Sandboxed** — Full macOS app sandbox for security
- **Security-scoped bookmarks** — Secure file access that persists across launches

---

## 📄 License

MIT License — See [LICENSE](LICENSE) for details.

---

## 🙏 Acknowledgments

- [Groq](https://groq.com) for their excellent Orpheus TTS API
- [OpenAI](https://openai.com) for their TTS API
- [Piper](https://github.com/rhasspy/piper) and the [rhasspy/piper-voices](https://huggingface.co/rhasspy/piper-voices) project for local neural TTS
- Apple's PDFKit, AVFoundation, NaturalLanguage, and AppKit speech frameworks
- The Swift and SwiftUI communities

---

<p align="center">
  Made with ❤️ for readers who love to listen
</p>

<p align="center">
  <a href="https://github.com/raakesh-m/FlowRead">⭐ Star this repo if you find it useful!</a>
</p>
