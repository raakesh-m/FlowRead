# FlowRead → Flutter (Android + iOS) Port Plan

> Goal: rebuild FlowRead as a single cross-platform Flutter app (one codebase, Android + iOS)
> while preserving the core experience: **PDF → sentence chunks → TTS with synchronized
> highlighting, smart auto-scroll, variable speed, session persistence.**
>
> This document focuses heavily on the **TTS engine strategy**, because that is the part that
> does *not* map 1:1 from the macOS app.

---

## 1. TL;DR — answers to the open questions

1. **Is there an offline/free on-device TTS like macOS Native?**
   **Yes.** Use **`flutter_tts`**, which wraps:
   - **iOS** → `AVSpeechSynthesizer` (the iOS sibling of macOS's `NSSpeechSynthesizer`)
   - **Android** → `android.speech.tts.TextToSpeech` (Google/Samsung engine)

   Both are **built-in, offline, free, no API key**. This is the direct replacement for the
   `macOSNative` engine. It even exposes a **word-boundary progress callback**, so highlighting
   can be word-level (better than today's sentence-level).

2. **Can we keep an offline *neural* (Piper-class) option without Python?**
   **Yes** — but not Piper-via-Python. Use **`sherpa_onnx`** (k2-fsa), which runs **Piper / VITS /
   Kokoro** ONNX models fully offline on Android & iOS via ONNX Runtime. No Python, no server.
   This is the mobile replacement for the desktop Piper engine.

3. **Do Groq / OpenAI carry over?**
   **Yes, unchanged.** They're just HTTPS calls returning audio bytes — fully portable. Same keys.

4. **VoxCPM on mobile?**
   **No on-device.** A 0.5B–2B PyTorch model won't run on a phone. If we want VoxCPM in the mobile
   app, it must be a **cloud endpoint** we host (OpenAI-compatible `/v1/audio/speech`, which VoxCPM
   supports via vLLM-Omni) and call like any other API engine.

---

## 2. Engine strategy (mobile)

| FlowRead (macOS) engine | Flutter (mobile) equivalent | How | Offline | Key | Notes |
|---|---|---|---|---|---|
| **macOS Native** (`NSSpeechSynthesizer`) | **Device Native** | `flutter_tts` → AVSpeechSynthesizer / Android TTS | ✅ | ❌ | Default engine. Free, instant, word-boundary highlighting. |
| **Piper** (Python + ONNX) | **On-device Neural** | `sherpa_onnx` (Piper/VITS/Kokoro ONNX) | ✅ | ❌ | Replaces Piper. Download model packs at runtime (like current Piper flow). |
| **Groq API** (Orpheus) | **Groq API** | `dio`/`http` POST → audio bytes → `just_audio` | ❌ | ✅ | Identical to desktop. |
| **OpenAI TTS** | **OpenAI TTS** | `dio`/`http` POST → audio bytes → `just_audio` | ❌ | ✅ | Identical to desktop. |
| **(new) VoxCPM** | **VoxCPM cloud** *(optional)* | Self-hosted OpenAI-compatible endpoint | ❌ | ✅ | Only if we stand up a server. Not on-device. |

**Recommended MVP:** Device Native (free, works for everyone) + Groq + OpenAI.
Add `sherpa_onnx` neural as phase 2 (it's the heaviest integration).

---

## 3. The on-device TTS deep dive (`flutter_tts`)

This is the heart of the answer to "is there a macOS-Native equivalent."

### What it gives us
- `speak(text)`, `pause()`, `stop()`
- `setLanguage(...)`, `setVoice({name, locale})`, `getVoices`, `getLanguages`
- `setSpeechRate(...)`, `setPitch(...)`, `setVolume(...)`
- **`setProgressHandler((text, startOffset, endOffset, word) {...})`** — fires per word while
  speaking → **drives synchronized highlighting** (native engines only; not on web).
- `setStartHandler`, `setCompletionHandler`, `setCancelHandler`, `setPauseHandler`,
  `setContinueHandler`, `setErrorHandler` → drive chunk progression (replaces the
  `currentChunkCompleted` Combine binding in `AudioPlaybackManager`).
- `synthesizeToFile(text, fileName)` — **Android + iOS** → produces a WAV/CAF you can play with
  `just_audio` (lets us reuse FlowRead's "synthesize → cache → play with variable speed" pipeline).
- `awaitSpeakCompletion(true)` — makes `speak()` await, simplifying the chunk loop.

### Two architectures — pick per engine

**Option A — Direct speak (simplest, best highlighting)**
`flutter_tts.speak(sentence)` + `setProgressHandler` for word highlighting +
`setCompletionHandler` to advance to the next chunk.
- ✅ Word-level highlighting for free
- ⚠️ Speed control is the platform's `setSpeechRate` (capped/normalized, not a true 0.5–2.0x audio rate)

**Option B — Synthesize-to-file + `just_audio` (matches FlowRead's current design)**
`synthesizeToFile()` → play file with `just_audio` `setSpeed(0.5–2.0)` (pitch-preserving) +
prefetch/cache like `AppState.audioCache`.
- ✅ Uniform pipeline across **all** engines (native + Groq + OpenAI all become "bytes → just_audio")
- ✅ True variable speed identical to desktop `AVAudioPlayer.rate`
- ⚠️ Loses word-boundary callbacks (progress handler only fires during `speak()`), so fall back to
  **sentence-level highlighting** — which is exactly what FlowRead does today, so no regression.

**Recommendation:** Use **Option B as the unified pipeline** (mirrors the existing architecture and
gives consistent speed control), with **Option A as an optional "native fast path"** for users who
want word-level highlighting on the free engine.

### Platform gotchas
- **Speech rate scales differ.** iOS normal speech rate ≈ 0.5 on a 0–1 scale; Android differs.
  Normalize behind our own `playbackSpeed` (0.5–2.0) → map per platform. (This is why Option B +
  `just_audio.setSpeed` is cleaner — true audio time-stretch instead of engine rate.)
- **Voice availability varies by device.** Enumerate with `getVoices` and let the user pick; don't
  hardcode "Samantha/Daniel" like the macOS app. Offer the system's enhanced/premium voices
  (user installs them in OS settings).
- **iOS audio session.** Call `setSharedInstance(true)` and configure the category so audio plays
  with the silent switch on and mixes/ducks correctly; needed for background playback.
- **Android API level.** Word-boundary progress requires API 26+ (fine for modern targets).

---

## 4. On-device neural (Piper replacement): `sherpa_onnx`

For users who want better-than-system quality offline (the Piper value prop):

- Package: **`sherpa_onnx`** (+ platform packages it pulls in). Pure on-device ONNX Runtime.
- Supported model families: **Piper (VITS)**, **VITS**, **Kokoro-82M** (multilingual, ~50+ langs).
- Same UX as desktop Piper: ship app small, **download the model pack on first use** with a
  progress sheet (reuse the `ModelDownloadManager` + `PiperSetupSheet` UX concept — but with **no
  Python step at all**, so it's strictly simpler than the macOS flow).
- Output is raw audio samples → write to WAV → play via `just_audio` (Option B pipeline).
- Model sizes: Piper voices ~60–120 MB each; Kokoro ~300 MB. Store under app documents dir.

> This is the cleanest part of the mobile story: it removes the entire fragile
> "system Python + pip install" dependency chain that the desktop Piper engine relies on.

---

## 5. Cloud engines (Groq / OpenAI) — straight port

No architectural change. Service classes become Dart classes:

- `GroqTtsService` / `OpenAiTtsService`: build JSON body (`model`, `input`, `voice`,
  `response_format`), POST with `dio`, get audio bytes back.
- Keep **Groq's 180-char chunk cap** and **OpenAI's 4096-char cap** logic — port the
  `splitTextIntoChunks` / `sanitizeText` / `isValidForTTS` helpers directly (they're pure logic).
- Keep **round-robin key rotation + failover** for Groq.
- Play returned WAV/MP3 with `just_audio`.
- **Key storage:** use **`flutter_secure_storage`** (Keychain / Keystore) instead of a plaintext
  `~/.flowread/api_keys.json`. Mobile users won't hand-edit JSON, and secure storage is expected.

---

## 6. Architecture mapping (Swift → Flutter)

| FlowRead (Swift/SwiftUI) | Flutter equivalent |
|---|---|
| `AppState : ObservableObject` (`@Published`) | `AppNotifier`/Riverpod providers (or Bloc) |
| `TTSManager` (routes to engine) | `TtsManager` (strategy over `TtsEngine` interface) |
| `TTSEngine` enum + per-engine services | `abstract class TtsEngine` + impls |
| `AudioPlaybackManager` (AVFoundation) | `just_audio` player + speed |
| `PDFTextProcessor` (PDFKit + NaturalLanguage) | PDF text extract + Dart sentence splitter |
| `PersistenceManager` (JSON in App Support) | `hive`/`isar` or `shared_preferences` |
| Security-scoped bookmarks | `file_picker` + copy into app sandbox / store URI |
| `ReadingPane` smart auto-scroll | `ScrollablePositionedList` / `scroll_to_index` |
| Preferences tabs (SwiftUI) | Settings screens (Flutter widgets) |

### Suggested project structure
```
lib/
  main.dart
  app/                 # app shell, theming, routing
  models/
    text_chunk.dart
    persisted_state.dart
    tts_engine.dart    # enum + metadata (mirrors TTSEngine.swift)
  services/
    tts/
      tts_manager.dart
      tts_engine_base.dart
      native_tts_service.dart    # flutter_tts
      sherpa_tts_service.dart    # sherpa_onnx (phase 2)
      groq_tts_service.dart
      openai_tts_service.dart
    audio/
      audio_player_service.dart  # just_audio + speed + cache + prefetch
    pdf/
      pdf_text_processor.dart    # extract + chunk (apiOptimized/natural strategies)
    storage/
      persistence_service.dart
      secure_keys_service.dart   # flutter_secure_storage
      model_download_service.dart
  state/               # Riverpod providers / notifiers
  ui/
    reader/            # reading pane, highlighting, auto-scroll
    controls/          # playback control bar
    settings/          # engine + voice + keys
```

---

## 7. PDF handling

Two viable stacks:

**A. Syncfusion (richest text extraction)**
- `syncfusion_flutter_pdf` → `PdfTextExtractor.extractText()` / `extractTextLines()` (with
  positions & fonts), `syncfusion_flutter_pdfviewer` for rendering.
- ⚠️ **Licensing:** free Community License only if your company/individual revenue is under the
  threshold (~US$1M) and team is small; otherwise paid. Check before shipping commercially.

**B. `pdfrx` (open-source, free)**
- Renders PDFs and exposes page text (`PdfPage` text loading). MIT-style license, no revenue cap.
- ✅ Recommended default to avoid licensing friction; fall back to Syncfusion only if you need its
  richer per-line/positional extraction.

**Sentence chunking:** Dart has no NaturalLanguage framework. Options:
- Port a rule-based splitter (the Groq/Piper `splitTextIntoChunks` logic is already rule-based and
  portable), plus the Roman-numeral → "Chapter N" smart detection from `PDFTextProcessor`.
- Keep the per-engine **chunking strategies** (`apiOptimized` 180/4000, `piperOptimized`,
  `natural`) — they're pure string logic.

---

## 8. Synchronized highlighting + auto-scroll

- **Highlighting source of truth:** current chunk index (sentence-level), same as desktop.
  Optionally upgrade to word-level on the native engine via `setProgressHandler`.
- **Rendering:** lay sentences out as a list (e.g. `ScrollablePositionedList`); the active
  sentence gets a highlight style; tap a sentence to jump (maps to `jumpToChunk`).
- **Auto-scroll:** use `scrollable_positioned_list`'s `itemScrollController.scrollTo(...)` to keep
  the active sentence in the upper ~25%; pause auto-scroll on manual drag, resume on next chunk —
  port the existing `ReadingPane` behavior.

---

## 9. Recommended package stack

| Concern | Package | Notes |
|---|---|---|
| On-device TTS (native) | `flutter_tts` | The macOS-Native equivalent. |
| On-device neural TTS | `sherpa_onnx` | Phase 2 — Piper/VITS/Kokoro offline. |
| Audio playback + speed | `just_audio` | `setSpeed` 0.5–2.0, pitch-preserving; gapless. |
| HTTP (Groq/OpenAI) | `dio` | Interceptors, cancellation, retries. |
| PDF text + render | `pdfrx` (or `syncfusion_flutter_pdf` + `_pdfviewer`) | Prefer pdfrx for licensing. |
| File picking | `file_picker` | Pick PDFs; copy into app sandbox. |
| State management | `flutter_riverpod` | Clean replacement for `ObservableObject`. |
| Persistence | `hive` / `isar` (+ `shared_preferences` for scalars) | Session state. |
| Secure key storage | `flutter_secure_storage` | Keychain / Keystore. |
| Paths | `path_provider` | App docs/support dirs for models + cache. |
| Scroll/highlight | `scrollable_positioned_list` | Active-sentence scrolling. |

> Versions move fast — pin against current pub.dev at implementation time.

---

## 10. Platform caveats checklist

- **iOS background audio:** add `audio` to `UIBackgroundModes`; configure audio session; consider
  `audio_service` if you want lock-screen controls / true background playback.
- **Android foreground service:** for long background playback, an `audio_service` foreground
  service + notification is the right pattern.
- **Permissions:** file access (scoped storage on Android 13+), notifications for download/playback.
- **App size:** keep the binary small; download neural model packs at runtime (as desktop does).
- **Network:** cloud engines need connectivity handling + graceful fallback to Device Native
  (mirror the desktop "Piper fails → fall back to macOS Native" safety net).
- **Speech-rate normalization:** centralize the 0.5–2.0 mapping; prefer `just_audio.setSpeed` for
  consistency across engines.

---

## 11. Phased roadmap

**Phase 0 — Skeleton**
Flutter project, theming, navigation, Riverpod scaffolding, PDF pick + render + text extract,
sentence chunking, reading pane with highlight + auto-scroll (no audio yet).

**Phase 1 — Device Native TTS (the MVP win)**
`flutter_tts` engine via the unified `just_audio` pipeline (Option B), playback controls, variable
speed, session persistence, secure key storage scaffolding. **Ships a fully working free offline app.**

**Phase 2 — Cloud engines**
Port Groq + OpenAI services (chunking, sanitization, key rotation), engine switcher + voice
pickers, settings UI.

**Phase 3 — On-device neural**
`sherpa_onnx` engine + model download manager + setup sheet (no Python!). Piper/Kokoro voices.

**Phase 4 — Polish / parity**
Background audio (`audio_service`), lock-screen controls, word-level highlighting on native engine,
Roman-numeral chapter detection, prefetch/caching tuning, accessibility.

**Phase 5 — (optional) VoxCPM cloud**
Stand up an OpenAI-compatible VoxCPM endpoint (vLLM-Omni) and add it as a cloud engine.

---

## 12. Key risks / decisions to make up front

1. **PDF library licensing** — pdfrx (free) vs Syncfusion (richer, license-gated). Decide early; it
   affects extraction code.
2. **Highlighting granularity** — sentence-level (uniform, matches desktop) vs word-level (nicer,
   native-only). Decide the default.
3. **Unified vs per-engine playback** — recommend the unified synthesize-to-file + `just_audio`
   pipeline; confirm acceptable (it's the lowest-risk path to feature parity).
4. **How much desktop logic to literally port** — the pure helpers (`splitTextIntoChunks`,
   `sanitizeText`, `isValidForTTS`, Roman-numeral detection, chunking strategies, key rotation) are
   directly translatable to Dart and should be reused, not reinvented.

---

### Sources
- [flutter_tts — pub.dev](https://pub.dev/packages/flutter_tts) · [changelog](https://pub.dev/packages/flutter_tts/changelog) · [API docs](https://pub.dev/documentation/flutter_tts/latest/flutter_tts/FlutterTts-class.html)
- [sherpa_onnx — pub.dev](https://pub.dev/packages/sherpa_onnx) · [k2-fsa/sherpa-onnx (GitHub)](https://github.com/k2-fsa/sherpa-onnx)
- [Syncfusion Flutter PDF text extraction](https://help.syncfusion.com/flutter/pdf/working-with-text-extraction)
- [just_audio — pub.dev](https://pub.dev/packages/just_audio)
