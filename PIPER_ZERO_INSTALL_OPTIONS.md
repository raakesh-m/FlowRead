# Piper TTS Zero-Installation Options for FlowRead

**Created:** 2026-02-02  
**Status:** Research & Planning  
**Goal:** Make Piper TTS work on macOS without requiring users to run `pip install piper-tts`

---

## Table of Contents

1. [Current Problem](#current-problem)
2. [Option 1: PyInstaller Bundle](#option-1-pyinstaller-bundle)
3. [Option 2: Native espeak-ng + Swift](#option-2-native-espeak-ng--swift)
4. [Option 3: piper-phonemize C++ Binary](#option-3-piper-phonemize-c-binary)
5. [Comparison Matrix](#comparison-matrix)
6. [Recommendation](#recommendation)

---

## Current Problem

### What Works Now
- ✅ `piper_phonemizer.py` script is bundled in the DMG
- ✅ ONNX Runtime is bundled for model inference
- ✅ Models download to `~/Library/Application Support/FlowRead/Models/`

### What's Broken
The `piper_phonemizer.py` script requires Python packages that are NOT bundled:

```python
from piper.phonemize_espeak import EspeakPhonemizer  # ❌ Requires pip install piper-tts
from piper.phoneme_ids import phonemes_to_ids        # ❌ Requires pip install piper-tts
```

**User Experience Problem:** Users must run `pip3 install piper-tts` in Terminal, which is unacceptable for a consumer DMG distribution.

---

## Option 1: PyInstaller Bundle

### Overview
Use **PyInstaller** to create a self-contained executable that bundles Python + piper-tts + all dependencies into a single binary.

### How It Works
```
┌─────────────────────────────────────────────────┐
│   FlowRead.app                                  │
│   ├── Contents/                                 │
│   │   ├── MacOS/FlowRead (Swift app)           │
│   │   ├── Resources/                           │
│   │   │   ├── piper_phonemizer (PyInstaller)   │  ← NEW: Self-contained binary
│   │   │   └── models/ (downloaded by user)     │
└─────────────────────────────────────────────────┘
```

### Step-by-Step Implementation

#### 1. Set Up Build Environment
```bash
# Create virtual environment for building
cd /path/to/FlowRead
python3 -m venv build_env
source build_env/bin/activate

# Install dependencies
pip install pyinstaller piper-tts
```

#### 2. Create the Phonemizer Script
Create a simple CLI wrapper (`piper_phonemizer_cli.py`):

```python
#!/usr/bin/env python3
"""
Standalone Piper phonemizer for FlowRead
Usage: ./piper_phonemizer <text> [--voice en-us]
"""
import sys
import argparse
import json
from piper.phonemize_espeak import EspeakPhonemizer
from piper.phoneme_ids import phonemes_to_ids

def main():
    parser = argparse.ArgumentParser(description='Phonemize text for Piper TTS')
    parser.add_argument('text', help='Text to phonemize')
    parser.add_argument('--voice', default='en-us', help='Voice/language code')
    args = parser.parse_args()
    
    phonemizer = EspeakPhonemizer(default_voice=args.voice)
    phonemes = phonemizer.phonemize(args.text)
    phoneme_ids = phonemes_to_ids(phonemes)
    
    # Output as JSON for easy parsing in Swift
    result = {
        "phonemes": phonemes,
        "phoneme_ids": phoneme_ids
    }
    print(json.dumps(result))

if __name__ == '__main__':
    main()
```

#### 3. Build with PyInstaller

**Single Architecture (arm64 OR x86_64):**
```bash
pyinstaller --onefile piper_phonemizer_cli.py \
    --name piper_phonemizer \
    --hidden-import=piper \
    --hidden-import=espeak_phonemizer \
    --collect-all piper \
    --collect-data espeak_phonemizer
```

**Universal Binary (arm64 + x86_64):**
```bash
# Requires universal Python installation
pyinstaller --onefile piper_phonemizer_cli.py \
    --name piper_phonemizer \
    --target-architecture universal2 \
    --hidden-import=piper \
    --collect-all piper
```

#### 4. Integrate with FlowRead

Update `PiperTTSService.swift` to call the bundled binary:
```swift
let phonemizerPath = Bundle.main.resourcePath! + "/piper_phonemizer"
let process = Process()
process.executableURL = URL(fileURLWithPath: phonemizerPath)
process.arguments = [text, "--voice", voice]
// ... execute and parse JSON output
```

### Pros & Cons

| Pros | Cons |
|------|------|
| ✅ Single file, easy to bundle | ⚠️ Adds 30-60 MB to app size |
| ✅ No user installation required | ⚠️ Build complexity (PyInstaller issues) |
| ✅ Works exactly like current Python script | ⚠️ Need to maintain Python build environment |
| ✅ Universal binary support | ⚠️ espeak data files need careful bundling |

### Estimated Size Impact
| Component | Size |
|-----------|------|
| Python runtime | ~15 MB |
| piper-tts package | ~5 MB |
| espeak-ng data | ~20 MB |
| Other dependencies | ~10 MB |
| **Total** | **~50 MB** |

### Known Issues & Solutions

**Issue 1: espeak-ng data not bundled**
```bash
# Add to PyInstaller command:
--add-data "/path/to/espeak-ng-data:espeak-ng-data"
```

**Issue 2: Architecture mismatch on Apple Silicon**
```bash
# Build separately for each arch, then use lipo:
lipo -create dist_arm64/piper_phonemizer dist_x86/piper_phonemizer -output piper_phonemizer_universal
```

**Issue 3: Code signing breaks the binary**
```bash
# Re-sign after bundling:
codesign --force --deep --sign - FlowRead.app
```

---

## Option 2: Native espeak-ng + Swift

### Overview
Eliminate Python entirely by:
1. Bundling the `espeak-ng` binary directly
2. Calling it to get IPA phonemes
3. Mapping phonemes to IDs in pure Swift

### How It Works
```
┌──────────────────────────────────────────────────────────────┐
│   FlowRead.app                                               │
│   ├── Contents/                                              │
│   │   ├── MacOS/FlowRead (Swift app)                        │
│   │   ├── Resources/                                        │
│   │   │   ├── espeak-ng (native binary)                     │  ← ~3 MB
│   │   │   ├── espeak-ng-data/ (language data)               │  ← ~20 MB
│   │   │   ├── phoneme_map.json (ID mapping)                 │  ← ~50 KB
│   │   │   └── models/ (downloaded by user)                  │
└──────────────────────────────────────────────────────────────┘
```

### Step-by-Step Implementation

#### 1. Install espeak-ng on Build Machine
```bash
# Using Homebrew
brew install espeak-ng

# Locate the binary and data
which espeak-ng                 # /opt/homebrew/bin/espeak-ng
ls /opt/homebrew/share/espeak-ng-data/
```

#### 2. Bundle espeak-ng Binary and Data
Copy to your app bundle:
```bash
cp /opt/homebrew/bin/espeak-ng FlowRead/Resources/
cp -r /opt/homebrew/share/espeak-ng-data FlowRead/Resources/
```

#### 3. Create Phoneme ID Mapping
Extract from a Piper model's JSON config (e.g., `amy_medium.onnx.json`):

```json
{
  "phoneme_id_map": {
    "_": 0,
    "^": 1,
    "$": 2,
    " ": 3,
    "!": 4,
    ...
    "ɪ": 45,
    "ɐ": 46,
    ...
  }
}
```

Save as `phoneme_map.json` in Resources.

#### 4. Swift Implementation

```swift
// PiperNativePhonemizerService.swift

import Foundation

class PiperNativePhonemizerService {
    private let espeakPath: String
    private let espeakDataPath: String
    private let phonemeMap: [String: Int]
    
    init() throws {
        guard let resourcePath = Bundle.main.resourcePath else {
            throw PhonemizerError.resourcesNotFound
        }
        
        espeakPath = resourcePath + "/espeak-ng"
        espeakDataPath = resourcePath + "/espeak-ng-data"
        
        // Load phoneme ID mapping
        let mapURL = URL(fileURLWithPath: resourcePath + "/phoneme_map.json")
        let data = try Data(contentsOf: mapURL)
        phonemeMap = try JSONDecoder().decode([String: Int].self, from: data)
    }
    
    /// Convert text to IPA phonemes using espeak-ng
    func textToPhonemes(_ text: String, voice: String = "en-us") throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: espeakPath)
        process.arguments = [
            "--ipa=3",           // IPA with underscore separators
            "-q",                // Quiet mode (no audio)
            "-v", voice,         // Voice/language
            "--path=\(espeakDataPath)",
            text
        ]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
    
    /// Convert IPA phonemes to Piper phoneme IDs
    func phonemesToIds(_ phonemes: String) -> [Int] {
        var ids: [Int] = []
        
        // Add start token
        if let startId = phonemeMap["^"] { ids.append(startId) }
        
        // Process each phoneme
        let phonemeChars = Array(phonemes)
        var i = 0
        while i < phonemeChars.count {
            // Try 2-character phonemes first (e.g., "aɪ")
            if i + 1 < phonemeChars.count {
                let bigram = String(phonemeChars[i...i+1])
                if let id = phonemeMap[bigram] {
                    ids.append(id)
                    i += 2
                    continue
                }
            }
            
            // Single character
            let char = String(phonemeChars[i])
            if let id = phonemeMap[char] {
                ids.append(id)
            } else if let padId = phonemeMap["_"] {
                // Unknown phoneme, use padding
                ids.append(padId)
            }
            i += 1
        }
        
        // Add end token
        if let endId = phonemeMap["$"] { ids.append(endId) }
        
        return ids
    }
    
    /// Full pipeline: text -> phoneme IDs
    func phonemize(_ text: String, voice: String = "en-us") throws -> [Int] {
        let phonemes = try textToPhonemes(text, voice: voice)
        return phonemesToIds(phonemes)
    }
}
```

### Pros & Cons

| Pros | Cons |
|------|------|
| ✅ No Python dependency at all | ⚠️ More complex implementation |
| ✅ Smaller size (~23 MB vs ~50 MB) | ⚠️ Need to maintain phoneme mapping |
| ✅ Native macOS binary | ⚠️ espeak-ng IPA output may differ from piper-phonemize |
| ✅ Cleaner architecture | ⚠️ Need to handle multi-byte IPA characters |
| ✅ Easier to code-sign | ⚠️ May have subtle phoneme differences |

### Estimated Size Impact
| Component | Size |
|-----------|------|
| espeak-ng binary | ~3 MB |
| espeak-ng-data | ~20 MB |
| phoneme_map.json | ~50 KB |
| **Total** | **~23 MB** |

### Phoneme Mapping Challenges

The main challenge is ensuring the espeak-ng IPA output matches what Piper expects. Here's why:

**espeak-ng output:**
```
Hello world → h_ə_l_oʊ_ _w_ɝ_l_d
```

**Piper expects:**
```
Phoneme IDs: [1, 45, 23, 67, 89, 3, 12, 34, 56, 78, 2]
```

The phoneme_id_map in the model's JSON file defines the mapping, but you need to:
1. Handle multi-character phonemes (diphthongs like "aɪ", "oʊ")
2. Handle stress markers (ˈ, ˌ)
3. Handle punctuation mapping
4. Match the exact phoneme set the model was trained on

---

## Option 3: piper-phonemize C++ Binary

### Overview
The Piper project has a **C++ library** called `piper-phonemize` that does exactly what we need without Python.

### How It Works
```
┌──────────────────────────────────────────────────────────────┐
│   FlowRead.app                                               │
│   ├── Contents/                                              │
│   │   ├── MacOS/FlowRead (Swift app)                        │
│   │   ├── Resources/                                        │
│   │   │   ├── piper_phonemize (C++ binary)                  │  ← ~5 MB
│   │   │   ├── libespeak-ng.dylib                            │  ← ~2 MB
│   │   │   ├── espeak-ng-data/                               │  ← ~20 MB
│   │   │   └── models/                                       │
└──────────────────────────────────────────────────────────────┘
```

### Building piper-phonemize for macOS

```bash
# Clone the repository
git clone https://github.com/rhasspy/piper-phonemize.git
cd piper-phonemize

# Checkout a stable version
git checkout fccd4f335aa68ac0b72600822f34d84363daa2bf -b build_branch

# Install dependencies
brew install cmake

# Build
make

# The binary will be at:
# ./install/bin/piper_phonemize
# ./install/lib/libespeak-ng.dylib
# ./install/share/espeak-ng-data/
```

### Usage
```bash
echo "Hello world" | ./piper_phonemize -l en-us --espeak-data ./espeak-ng-data/
# Output: {"phoneme_ids": [1, 45, 23, ...], "phonemes": "həloʊ wɝld"}
```

### Pros & Cons

| Pros | Cons |
|------|------|
| ✅ Official Piper tool | ⚠️ Repository is archived (July 2025) |
| ✅ Exact phoneme matching | ⚠️ C++ build complexity on macOS |
| ✅ No Python at all | ⚠️ Need to bundle dylib libraries |
| ✅ JSON output (easy parsing) | ⚠️ May need universal binary lipo |

### Estimated Size Impact
| Component | Size |
|-----------|------|
| piper_phonemize binary | ~5 MB |
| libespeak-ng.dylib | ~2 MB |
| espeak-ng-data | ~20 MB |
| **Total** | **~27 MB** |

---

## Comparison Matrix

| Criteria | PyInstaller | espeak-ng + Swift | piper-phonemize C++ |
|----------|-------------|-------------------|---------------------|
| **Size Impact** | ~50 MB | ~23 MB | ~27 MB |
| **Implementation Complexity** | Medium | High | Medium |
| **Phoneme Accuracy** | ✅ Exact match | ⚠️ May differ | ✅ Exact match |
| **Build Complexity** | Medium | Low | High |
| **Maintenance** | Medium | High | Low |
| **No Python Required** | ❌ Bundled | ✅ None | ✅ None |
| **Universal Binary** | ⚠️ Complex | ✅ Easy | ⚠️ Complex |
| **Future Proof** | ✅ Python ecosystem | ⚠️ Manual updates | ⚠️ Archived repo |

---

## Recommendation

### Best Option: **piper-phonemize C++ Binary**

For FlowRead, I recommend **Option 3 (piper-phonemize C++)** because:

1. **Exact phoneme matching** - Uses the same code as Piper's training pipeline
2. **No Python complexity** - Clean native binary
3. **Reasonable size** - ~27 MB is acceptable
4. **JSON output** - Easy to parse in Swift

### Implementation Steps

1. Build `piper-phonemize` from source for macOS (universal binary)
2. Bundle the binary, dylib, and data in the app
3. Update `PiperTTSService.swift` to call the C++ binary
4. Remove Python phonemizer script

### Alternative: **espeak-ng + Swift** (Option 2)

If you want the smallest footprint and are willing to handle phoneme mapping:
- Only ~23 MB added
- Completely native Swift
- But requires careful phoneme mapping maintenance

### Skip Piper for End Users

If the complexity is too high, consider:
- **macOS Native + OpenAI** covers 99% of users
- Keep Piper as "developer mode" for those who install piper-tts

---

## Next Steps

1. [ ] Choose preferred option
2. [ ] Build and test the phonemizer binary
3. [ ] Update Package.swift to include new resources
4. [ ] Modify PiperTTSService.swift to use new approach
5. [ ] Test on both Intel and Apple Silicon Macs
6. [ ] Rebuild DMG and test full flow

---

## References

- [PyInstaller Documentation](https://pyinstaller.org/en/stable/)
- [piper-phonemize GitHub](https://github.com/rhasspy/piper-phonemize)
- [espeak-ng GitHub](https://github.com/espeak-ng/espeak-ng)
- [Piper TTS GitHub](https://github.com/rhasspy/piper)
