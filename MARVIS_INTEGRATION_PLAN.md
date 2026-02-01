# Marvis TTS Integration Plan for FlowRead

**Date:** 2026-01-30
**Target Platform:** macOS (Apple Silicon M4)
**Current Status:** Research Phase
**Estimated Implementation Time:** 2-3 days

---

## Table of Contents
1. [Executive Summary](#executive-summary)
2. [Technical Architecture](#technical-architecture)
3. [Implementation Approaches](#implementation-approaches)
4. [Recommended Approach](#recommended-approach)
5. [Implementation Phases](#implementation-phases)
6. [Technical Challenges](#technical-challenges)
7. [Integration Steps](#integration-steps)
8. [Testing Strategy](#testing-strategy)
9. [Rollback Plan](#rollback-plan)
10. [Resources & References](#resources--references)

---

## Executive Summary

### What is Marvis TTS?

**Marvis TTS v0.1** is a 250M parameter text-to-speech model optimized for Apple Silicon, released by Marvis-AI under Apache 2.0 license. It addresses FlowRead's primary pain point: **long sentence handling**.

### Key Advantages Over Piper

| Feature | Piper | Marvis TTS |
|---------|-------|------------|
| **Sequence Limit** | ~400 phoneme IDs (~300 chars) | **No hard limit** - processes full context |
| **Long Sentence Behavior** | Fast "auctioneer" speech | Natural pacing maintained |
| **Architecture** | VITS-based ONNX | Dual-transformer with MLX |
| **Apple Silicon** | Generic ONNX Runtime | **Native MLX optimization** |
| **Streaming** | No | **Real-time streaming** |
| **Model Size** | 126 MB (2 voices) | **500 MB quantized** (2 voices) |
| **English Voices** | Amy, Ryan | conversational_a (F), conversational_b (M) |
| **Quality** | Very Good | Very Good |

### The Big Picture

**Problem:** Your 409-character sentences cause Piper to produce fast, unintelligible speech.

**Solution:** Marvis processes entire text sequences contextually without chunking, maintaining natural prosody across any length.

**Trade-off:** Requires Python runtime integration (MLX-audio) vs. current pure-Swift ONNX approach.

---

## Technical Architecture

### Current FlowRead Architecture (Piper)

```
┌─────────────────────────────────────────────────┐
│  Swift App (FlowRead)                           │
│  ├── PiperTTSService.swift                      │
│  │   ├── Loads ONNX model via OnnxRuntime       │
│  │   ├── Calls Python script for phonemization │
│  │   │   └── piper_phonemizer.py (espeak-ng)   │
│  │   ├── Runs ONNX inference                    │
│  │   └── Returns WAV audio                      │
│  │                                               │
│  ├── ModelDownloadManager.swift                 │
│  │   └── Downloads .onnx + .json from HF        │
│  │                                               │
│  └── TTSManager.swift (orchestrator)            │
└─────────────────────────────────────────────────┘
```

### Proposed Marvis Architecture

```
┌──────────────────────────────────────────────────────────┐
│  Swift App (FlowRead)                                    │
│  ├── MarvisTTSService.swift (NEW)                       │
│  │   ├── Calls Python script via Process               │
│  │   │   └── marvis_tts_inference.py (NEW)             │
│  │   │       ├── Imports mlx_audio.tts                 │
│  │   │       ├── Loads Marvis model from HF            │
│  │   │       ├── Generates audio (streaming capable)   │
│  │   │       └── Returns WAV via stdout/file           │
│  │   └── Receives audio data                           │
│  │                                                       │
│  ├── ModelDownloadManager.swift (MODIFIED)              │
│  │   ├── Checks for Python + mlx-audio installation    │
│  │   ├── Downloads Marvis model on first use           │
│  │   │   (handled automatically by mlx-audio)          │
│  │   └── Status tracking for Marvis model              │
│  │                                                       │
│  ├── TTSEngine.swift (MODIFIED)                         │
│  │   └── Add .marvis case                              │
│  │                                                       │
│  └── TTSManager.swift (MODIFIED)                        │
│      └── Add synthesizeWithMarvis() method              │
└──────────────────────────────────────────────────────────┘
```

---

## Implementation Approaches

### Approach 1: Python Script via Process (RECOMMENDED)

**How it works:**
- Swift calls Python script using `Process` class
- Python script uses `mlx-audio` library to run inference
- Returns WAV audio via file or stdout
- Similar to current `piper_phonemizer.py` pattern

**Pros:**
- ✅ Matches existing architecture pattern
- ✅ Minimal Swift code changes
- ✅ Easy debugging (can test Python script independently)
- ✅ No complex bridging layers
- ✅ User can install Python dependencies separately

**Cons:**
- ❌ Requires Python runtime on user's system
- ❌ Inter-process communication overhead
- ❌ Model downloaded to user's cache (~500MB)

**Complexity:** Medium

---

### Approach 2: Embedded Python Runtime (py2app)

**How it works:**
- Bundle Python interpreter + dependencies inside .app
- Use PyObjC bridge to call Python from Swift
- Distribute as single self-contained app

**Pros:**
- ✅ No external dependencies
- ✅ One-click installation for users

**Cons:**
- ❌ App size increases by ~200-300MB (Python + MLX + dependencies)
- ❌ Complex build process (py2app setup)
- ❌ MLX.metallib bundling complications
- ❌ App Store distribution challenges
- ❌ Code signing complexity

**Complexity:** High

---

### Approach 3: mlx-audio-swift Package

**How it works:**
- Use native Swift package `mlx-audio-swift`
- Direct Swift API calls (no Python)
- Models load from HuggingFace automatically

**Pros:**
- ✅ Pure Swift solution
- ✅ No Python runtime needed
- ✅ Best performance (native MLX)
- ✅ Clean integration

**Cons:**
- ❌ Package is very new and experimental
- ❌ Limited documentation
- ❌ Requires copying model files to Resources
- ❌ Less flexible than Python approach
- ❌ May not support all mlx-audio features

**Complexity:** Medium-High

**Status:** Package exists but lacks comprehensive documentation. Would need experimentation.

---

## Recommended Approach

### **Approach 1: Python Script via Process**

**Rationale:**
1. **Proven Pattern:** Already using Python for `piper_phonemizer.py`
2. **Minimal Risk:** No major architectural changes
3. **Flexible:** Easy to swap models or update libraries
4. **Debuggable:** Can test Python script independently
5. **Fast Implementation:** 1-2 days vs. weeks for other approaches

**User Experience:**
- First-time setup: User installs Python + mlx-audio (5 minutes)
- Subsequent use: Seamless, just like Piper
- Model auto-downloads on first use (~500MB, one-time)

---

## Implementation Phases

### Phase 1: Python Script Development (Day 1 Morning)

**Goal:** Create working `marvis_tts_inference.py` script

**Tasks:**
1. ✅ Create `marvis_tts_inference.py` in `FlowRead/Services/`
2. ✅ Implement command-line interface:
   ```bash
   python marvis_tts_inference.py "Text to synthesize" --voice conversational_a --output audio.wav
   ```
3. ✅ Handle model auto-download (first use)
4. ✅ Implement error handling:
   - MLX not installed
   - Model download failure
   - Inference errors
5. ✅ Test standalone (outside Swift)

**Script Structure:**
```python
#!/usr/bin/env python3
import sys
import argparse
from mlx_audio.tts import load_model
import soundfile as sf

def synthesize(text, voice="conversational_a", output_path="output.wav"):
    try:
        # Load model (auto-downloads on first use)
        model = load_model("Marvis-AI/marvis-tts-250m-v0.1")

        # Generate audio
        for result in model.generate(text, voice=voice):
            audio = result.audio  # MLX array

        # Convert to numpy and save
        audio_np = audio.__array__()
        sf.write(output_path, audio_np, 24000)

        return True
    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return False

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("text", help="Text to synthesize")
    parser.add_argument("--voice", default="conversational_a")
    parser.add_argument("--output", default="output.wav")
    args = parser.parse_args()

    success = synthesize(args.text, args.voice, args.output)
    sys.exit(0 if success else 1)
```

---

### Phase 2: Swift Service Implementation (Day 1 Afternoon)

**Goal:** Create `MarvisTTSService.swift` that calls Python script

**Tasks:**
1. ✅ Create `MarvisTTSService.swift` in `FlowRead/Services/`
2. ✅ Implement similar pattern to `PiperTTSService`:
   - Model loading check
   - Voice selection
   - Audio synthesis
3. ✅ Handle Python script execution via `Process`
4. ✅ Parse output/errors
5. ✅ Return audio data

**Code Structure:**
```swift
@MainActor
class MarvisTTSService: ObservableObject {
    private var selectedVoice: MarvisVoice = .conversational_a

    func synthesize(text: String) async throws -> Data? {
        // Find Python script
        let scriptPath = locatePythonScript()

        // Create temp file for output
        let tempFile = createTempAudioFile()

        // Run Python script
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = [
            scriptPath,
            text,
            "--voice", selectedVoice.rawValue,
            "--output", tempFile.path
        ]

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw MarvisTTSError.synthesizeFailed
        }

        // Read audio file
        let audioData = try Data(contentsOf: tempFile)
        try? FileManager.default.removeItem(at: tempFile)

        return audioData
    }
}
```

---

### Phase 3: Model & Voice Management (Day 2 Morning)

**Goal:** Integrate Marvis into existing model management system

**Tasks:**
1. ✅ Add `MarvisVoice` enum to `TTSEngine.swift`:
   ```swift
   enum MarvisVoice: String, CaseIterable {
       case conversational_a = "conversational_a"
       case conversational_b = "conversational_b"

       var displayName: String {
           self == .conversational_a ? "Female" : "Male"
       }
   }
   ```

2. ✅ Add `.marvis` case to `TTSEngine`:
   ```swift
   case marvis = "marvis"
   ```

3. ✅ Update `ModelDownloadManager`:
   - Add `marvisStatus` property
   - Implement `checkMarvisInstallation()` - checks for:
     - Python 3.10+ installed
     - mlx-audio package installed
     - Model cached (if previously downloaded)
   - Add UI status indicators

4. ✅ Add installation helper:
   - Guide user to install: `pip install mlx-audio`
   - Provide diagnostic output

---

### Phase 4: TTSManager Integration (Day 2 Afternoon)

**Goal:** Wire Marvis into playback system

**Tasks:**
1. ✅ Add `synthesizeWithMarvis()` to `TTSManager`
2. ✅ Update `synthesize()` switch statement
3. ✅ Handle Marvis-specific errors
4. ✅ Add voice selection UI for Marvis
5. ✅ Test end-to-end synthesis

---

### Phase 5: Testing & Optimization (Day 3)

**Goal:** Ensure production readiness

**Tasks:**
1. ✅ **Unit Tests:**
   - Python script with various text lengths
   - Error handling (missing Python, failed downloads)
   - Voice switching
   - Long text (400+ characters)

2. ✅ **Integration Tests:**
   - PDF reading flow
   - Playback controls
   - Engine switching (Piper → Marvis → Native)
   - Error recovery

3. ✅ **Performance Tests:**
   - First synthesis (with model download): ~30-60 seconds
   - Subsequent synthesis: ~2-5 seconds per sentence
   - Memory usage monitoring
   - Streaming capability (future)

4. ✅ **User Experience:**
   - Installation documentation
   - Error messages clarity
   - Progress indicators for model download
   - Voice preview samples

---

## Technical Challenges

### Challenge 1: Python Runtime Dependency

**Problem:** Marvis requires Python 3.10+ with mlx-audio installed.

**Solutions:**
1. **Detect Python installation:**
   ```swift
   func checkPythonInstallation() -> Bool {
       let process = Process()
       process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
       process.arguments = ["--version"]
       // Check if Python 3.10+
   }
   ```

2. **Check mlx-audio package:**
   ```swift
   func checkMLXAudio() -> Bool {
       let process = Process()
       process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
       process.arguments = ["-c", "import mlx_audio"]
       // Returns 0 if installed
   }
   ```

3. **Provide installation guide:**
   - In-app instructions
   - Copy command to clipboard: `pip install mlx-audio`
   - Link to troubleshooting docs

**Mitigation:** Clear error messages with actionable steps.

---

### Challenge 2: Model Download (500MB)

**Problem:** First use downloads large model files.

**Solutions:**
1. **Progress tracking:**
   - Monitor model cache directory
   - Estimate download progress (not directly accessible)
   - Show spinner with estimated time

2. **Pre-download option:**
   - Add "Download Model Now" button in settings
   - Run Python script with dummy text to trigger download
   - Cache location: `~/.cache/huggingface/hub/`

3. **Fallback behavior:**
   - If download fails, fall back to Piper
   - Retry mechanism
   - Offline check before attempting

**Mitigation:** User education + progress indicators.

---

### Challenge 3: Sandboxing & Permissions

**Problem:** macOS sandbox restricts subprocess execution and file access.

**Solutions:**
1. **Required Entitlements:**
   Add to `FlowRead.entitlements`:
   ```xml
   <key>com.apple.security.app-sandbox</key>
   <true/>
   <key>com.apple.security.files.user-selected.read-write</key>
   <true/>
   <key>com.apple.security.network.client</key>
   <true/>
   <key>com.apple.security.temporary-exception.files.home-relative-path.read-write</key>
   <array>
       <string>.cache/huggingface/</string>
   </array>
   ```

2. **Python Execution:**
   - Use `/usr/bin/python3` (system Python)
   - Avoid virtual environments (sandbox conflicts)
   - Set `PYTHONPATH` if needed

3. **Temp File Strategy:**
   - Use app's sandbox temp directory
   - Clean up after synthesis
   - Ensure proper permissions

**Mitigation:** Test on sandboxed build early.

---

### Challenge 4: Error Handling

**Problem:** Many failure points (Python missing, package missing, model download, inference).

**Error Hierarchy:**
```swift
enum MarvisTTSError: Error {
    case pythonNotInstalled
    case mlxAudioNotInstalled
    case modelDownloadFailed
    case scriptNotFound
    case synthesizeFailed(String)
    case invalidAudioData
}
```

**User-Facing Messages:**
- ✅ "Python 3.10+ required. [Install Guide]"
- ✅ "Installing mlx-audio package... [Copy Command]"
- ✅ "Downloading Marvis model (500MB, one-time)..."
- ✅ "Synthesis failed. Retrying..."
- ✅ "Falling back to Piper TTS"

**Mitigation:** Graceful degradation + helpful error messages.

---

## Integration Steps

### Step 1: Create Python Infrastructure

**Files to create:**
```
FlowRead/Services/
├── marvis_tts_inference.py (NEW)
└── marvis_tts_check.py (NEW - diagnostic script)
```

**marvis_tts_check.py:**
```python
#!/usr/bin/env python3
"""
Diagnostic script to check Marvis TTS readiness.
Returns JSON with status information.
"""
import sys
import json

def check_installation():
    status = {
        "python_version": sys.version,
        "mlx_audio_installed": False,
        "model_cached": False,
        "ready": False
    }

    try:
        import mlx_audio
        status["mlx_audio_installed"] = True
        status["mlx_audio_version"] = mlx_audio.__version__
    except ImportError:
        pass

    # Check model cache
    import os
    cache_path = os.path.expanduser("~/.cache/huggingface/hub/")
    if os.path.exists(cache_path):
        # Look for Marvis model
        for item in os.listdir(cache_path):
            if "marvis" in item.lower():
                status["model_cached"] = True
                break

    status["ready"] = status["mlx_audio_installed"]

    print(json.dumps(status))
    return 0

if __name__ == "__main__":
    sys.exit(check_installation())
```

---

### Step 2: Add Swift Service

**Files to modify/create:**
```
FlowRead/Services/
├── MarvisTTSService.swift (NEW)
└── TTSManager.swift (MODIFY)

FlowRead/Models/
└── TTSEngine.swift (MODIFY)
```

**Key Methods:**
- `checkInstallation() -> MarvisInstallationStatus`
- `synthesize(text:) async throws -> Data?`
- `setVoice(_ voice:)`
- `getVoice() -> MarvisVoice`

---

### Step 3: Update Model Management

**Files to modify:**
```
FlowRead/Services/
└── ModelDownloadManager.swift (MODIFY)

FlowRead/Views/
└── TTSPreferencesView.swift (MODIFY)
```

**Add:**
- Installation status UI
- Voice selection for Marvis
- Diagnostic button to check readiness
- Link to installation instructions

---

### Step 4: UI Integration

**TTSPreferencesView additions:**
```swift
// Marvis section
if ttsEngine == .marvis {
    Section("Marvis TTS") {
        // Installation status
        HStack {
            Text("Status")
            Spacer()
            if marvisReady {
                Label("Ready", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Label("Setup Required", systemImage: "exclamationmark.triangle")
                    .foregroundColor(.orange)
            }
        }

        // Voice selection
        Picker("Voice", selection: $marvisVoice) {
            ForEach(MarvisVoice.allCases) { voice in
                Text(voice.displayName).tag(voice)
            }
        }

        // Diagnostic button
        Button("Check Installation") {
            Task {
                await runDiagnostics()
            }
        }

        // Installation guide link
        Link("Installation Guide", destination: URL(string: "...")!)
    }
}
```

---

## Testing Strategy

### Manual Testing Checklist

**Installation Flow:**
- [ ] Fresh install (no Python) - shows error
- [ ] Python installed, no mlx-audio - shows error + install command
- [ ] Full installation - shows "Ready"
- [ ] Model download on first use - shows progress
- [ ] Subsequent uses - fast synthesis

**Synthesis Testing:**
- [ ] Short text (20 chars)
- [ ] Medium text (200 chars)
- [ ] Long text (400+ chars) - **KEY TEST**
- [ ] Very long text (1000+ chars)
- [ ] Special characters, punctuation
- [ ] Multiple languages (English only expected to work well)

**Voice Testing:**
- [ ] conversational_a (female)
- [ ] conversational_b (male)
- [ ] Voice switching mid-session

**Error Recovery:**
- [ ] Network failure during model download
- [ ] Python script crash
- [ ] Invalid text input
- [ ] Fall back to Piper works correctly

**Integration Testing:**
- [ ] PDF reading with Marvis
- [ ] Playback controls (play/pause/stop)
- [ ] Engine switching (Piper ↔ Marvis ↔ Native)
- [ ] Concurrent requests handling

---

## Rollback Plan

### If Integration Fails

**Option 1: Disable Marvis**
- Remove `.marvis` from TTSEngine
- Hide UI options
- Keep code for future retry

**Option 2: Keep as Experimental**
- Add "Experimental" badge
- Require explicit opt-in
- Document known issues

**Option 3: Complete Removal**
- Revert all code changes
- Remove Python scripts
- Git reset to pre-integration commit

**Risk Mitigation:**
- Work in feature branch
- Merge only after full testing
- Keep Piper as primary engine
- Document all changes clearly

---

## Resources & References

### Official Documentation
- [Marvis TTS HuggingFace](https://huggingface.co/Marvis-AI/marvis-tts-250m-v0.1)
- [MLX Audio GitHub](https://github.com/Blaizzy/mlx-audio)
- [MLX Framework Docs](https://ml-explore.github.io/mlx/)
- [Marvis TTS Blog Post](https://huggingface.co/blog/prince-canuma/introducing-marvis-tts)

### Implementation Guides
- [Local TTS with mlx-audio](https://blog.johnys.io/local-text-to-speech-tts-and-voice-cloning-with-mlx-audio/)
- [Swift Process Usage](https://developer.apple.com/forums/thread/30092)
- [Python Subprocess Sandboxing](https://zameermanji.com/blog/2025/4/1/sandboxing-subprocesses-in-python-on-macos/)
- [macOS App Sandbox Guide](https://developer.apple.com/library/archive/documentation/Miscellaneous/Reference/EntitlementKeyReference/Chapters/EnablingAppSandbox.html)

### Related Projects
- [mlx-audio-swift](https://github.com/Blaizzy/mlx-audio-swift) - Native Swift alternative
- [Marvis Labs GitHub](https://github.com/Marvis-Labs/marvis-tts)
- [Kokoro TTS](https://huggingface.co/hexgrad/Kokoro-82M) - Alternative model

### Troubleshooting
- [py2app Documentation](https://py2app.readthedocs.io/en/latest/)
- [MLX Build Issues](https://github.com/ml-explore/mlx/issues)
- [PyObjC Bridge](https://pyobjc.readthedocs.io/)

---

## Decision Summary

### Why Marvis?
✅ Solves long sentence problem (no 300-char limit)
✅ Native Apple Silicon optimization
✅ Real-time streaming capability
✅ No sequence-related quality degradation
✅ Apache 2.0 license (commercial-friendly)

### Why Python Script Approach?
✅ Matches existing pattern (piper_phonemizer.py)
✅ Fast to implement (1-2 days)
✅ Easy to debug and maintain
✅ Flexible for future changes
✅ No complex build tooling

### Trade-offs Accepted
❌ Python runtime dependency (user must install)
❌ 500MB model download (one-time)
❌ Inter-process communication overhead
❌ Cannot distribute as single .app bundle

### Next Steps
1. **Day 1:** Implement Python script + Swift service
2. **Day 2:** Integrate with UI and model management
3. **Day 3:** Test thoroughly + document
4. **Review:** User testing with long sentences
5. **Decision:** Ship or iterate based on feedback

---

**Document Version:** 1.0
**Last Updated:** 2026-01-30
**Author:** Claude (Sonnet 4.5)
**Status:** Ready for Implementation
