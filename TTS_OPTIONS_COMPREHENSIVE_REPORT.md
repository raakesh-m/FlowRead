# Comprehensive TTS Options Report for FlowRead

**Generated:** 2026-02-01
**Current Version:** FlowRead v1.0.0

---

## Table of Contents

1. [Current FlowRead Architecture](#current-flowread-architecture)
2. [Paid Cloud TTS APIs](#paid-cloud-tts-apis)
3. [Free Cloud TTS Options](#free-cloud-tts-options)
4. [Open-Source Self-Hosted Options](#open-source-self-hosted-options)
5. [Comparison Tables](#comparison-tables)
6. [Implementation Recommendations](#implementation-recommendations)
7. [Technical Integration Notes](#technical-integration-notes)
8. [Cost Analysis](#cost-analysis)
9. [Sources](#sources)

---

## Current FlowRead Architecture

### Existing TTS Engines

FlowRead currently implements **three TTS engines** orchestrated by `TTSManager.swift`:

#### 1. **Piper TTS (Local AI)**
- **Location:** `FlowRead/Services/PiperTTSService.swift`
- **Technology:** ONNX Runtime with Python phonemizer
- **Models:**
  - Amy (Female, US English, Medium quality)
  - Ryan (Male, US English, Medium quality)
- **Model Storage:** `~/Library/Application Support/FlowRead/Models/`
- **Model Size:** ~63MB each (.onnx + .json config)
- **Source:** Hugging Face (rhasspy/piper-voices)

**Pipeline:**
```
Text (≤300 chars) → piper_phonemizer.py (Python/espeak-ng)
→ Phoneme IDs (JSON) → ORTSession.run() (ONNX Runtime)
→ Float32 audio → PCM conversion → WAV output
```

**Features:**
- Smart text chunking (sentences → punctuation → conjunctions → words)
- Dynamic normalization for audio quality
- 22,050 Hz sample rate
- Lazy model loading
- Completely offline after model download

#### 2. **Groq TTS (Cloud API)**
- **Location:** `FlowRead/Services/GroqTTSService.swift`
- **Endpoint:** `https://api.groq.com/openai/v1/audio/speech`
- **Model:** `canopylabs/orpheus-v1-english`
- **Voices:** 6 voices (Autumn, Diana, Hannah, Austin, Daniel, Troy)
- **Text Limit:** 180 chars per request

**Features:**
- API key rotation (supports 5+ keys)
- Rate-limit handling with failed key tracking
- Text sanitization and validation
- Actor-based concurrency for thread safety
- Config: `~/.flowread/api_keys.json` + environment variables

#### 3. **Native TTS (macOS System)**
- **Location:** `FlowRead/Services/NativeTTSService.swift`
- **Technology:** `NSSpeechSynthesizer` (AppKit)
- **Voices:** Samantha (Female, American), Daniel (Male, British)
- **Format:** AIFF audio output
- **Features:**
  - Completely offline
  - No models needed
  - Asynchronous synthesis with delegate pattern
  - Acts as fallback when Piper fails

### Audio Playback System

**AudioPlaybackManager** (`FlowRead/Services/AudioPlaybackManager.swift`):
- `AVAudioPlayer` (AVFoundation)
- Formats: WAV, AIFF, MP3
- Variable speed: 0.5x - 2.0x
- Progress tracking (0.1s intervals)
- Seek capability

### Python Bundling Strategy

**Script:** `piper_phonemizer.py`
- **Bundling:** Swift Package Manager (`.copy()` in Package.swift)
- **Runtime:** System Python (`/usr/bin/python3`)
- **Dependencies:** `piper-tts` package (user must install)
- **Location in bundle:** `FlowRead.app/Contents/Resources/piper_phonemizer.py`

### Logging System

**Logger.swift:**
- File-based: `~/Library/Application Support/FlowRead/Logs/flowread_{timestamp}.log`
- Levels: DEBUG, INFO, WARNING, ERROR, CRITICAL
- Async writing via DispatchQueue
- Console + file simultaneous output

---

## Paid Cloud TTS APIs

### Top-Tier Premium Services

#### 1. **OpenAI TTS API**
- **Pricing:**
  - Standard: $15/1M characters
  - HD: $30/1M characters
  - Mini: $0.60/1M characters
- **Latency:** ~200ms
- **Voices:** 11 built-in voices
- **Features:**
  - Real-time streaming support
  - Well-documented API
  - Reliable infrastructure
- **Best For:** General use, balanced cost/quality
- **Free Credits:** $5 for new accounts (expires in 3 months)

#### 2. **ElevenLabs**
- **Latency:** 75ms (Flash v2.5) - **Ultra-fast**
- **Voices:** 380+ voices across 70+ languages
- **Quality Ranking:** Most natural-sounding TTS available
- **Features:**
  - Voice cloning
  - Emotion control
  - Multi-speaker support
- **Free Tier:** ~10,000 chars/month
- **Best For:** When quality > cost, narration, audiobooks, creative projects
- **Note:** More expensive than OpenAI but faster and more natural

#### 3. **Inworld TTS**
- **Models:**
  - TTS-1.5-Max: $10/1M chars
  - TTS-1.5-Mini: $5/1M chars
- **Quality:** #1 ranked (ELO score: 1,160 from blind tests)
- **Latency:** <250ms
- **Best For:** Real-time voice agents, highest quality requirements

### Ultra-Low Latency Specialists

#### 4. **Cartesia Sonic 3**
- **Latency:** **40ms TTFA** (Time-to-First-Audio) - **FASTEST AVAILABLE**
- **Technology:** State Space Model (SSM) architecture
- **Features:**
  - AI-generated laughter
  - Emotion control
  - Real-time conversational AI
- **Best For:** Real-time conversations, interactive voice agents

#### 5. **Murf Falcon**
- **Latency:**
  - 55ms model latency
  - 130ms TTFA (consistent globally)
- **Pricing:** $0.01/minute (**extremely competitive**)
- **Voices:** 150+ voices, 35+ languages
- **Best For:** Cost-effective low-latency needs

#### 6. **Hume AI Octave 2**
- **Latency:** ~100ms (200ms TTFT with streaming)
- **Pricing:** **$7.60/1M chars** (cheapest among top providers)
- **Features:**
  - Emotion-aware synthesis
  - Speech-to-speech <300ms (EVI 3)
- **Best For:** Budget-conscious projects needing speed

### Cost-Effective Cloud Option

#### 7. **Speechmatics**
- **Pricing:** **$0.011/1K chars** (11-27× cheaper than ElevenLabs)
- **Latency:** ~150ms streaming
- **Languages:** English-only (expanding throughout 2026)
- **TTFA:** ~150ms
- **Best For:** High-volume English TTS applications

### Enterprise/Hyperscaler Options

#### 8. **Google Cloud Text-to-Speech**
- **Technology:** WaveNet neural voices
- **Voices:** 380+ voices, 75+ languages (**most multilingual**)
- **Free Tier:**
  - 1M chars/month (WaveNet)
  - 4M chars/month (Standard voices)
  - $300 credits for new customers
- **Quality:** WaveNet = very high quality
- **Best For:** Multilingual applications, Google ecosystem

#### 9. **Microsoft Azure Neural TTS**
- **Free Tier:**
  - Free (F0) tier with limited usage
  - $200 credits for new accounts (~400K chars)
- **Paid:** $16/1M chars (neural voices)
- **Features:**
  - Custom Neural Voices (create branded voices)
  - Enterprise SLA
  - Microsoft ecosystem integration
- **Best For:** Enterprise deployments, custom branding

#### 10. **Amazon Polly**
- **Free Tier:** 5M chars/month (first year only)
- **Paid:** $4/1M chars (after first year)
- **Voices:** Neural + standard options, 36 languages
- **Features:**
  - Speech marks (metadata)
  - Advanced SSML support
  - AWS ecosystem integration
  - Pay-as-you-go pricing
- **Best For:** AWS ecosystem, flexible pricing needs

### Specialized Services

#### 11. **Deepgram Aura**
- **Focus:** API-first developer experience
- **Features:** Seamless integration, modern API design
- **Best For:** API-first applications

#### 12. **Respeecher Real-Time TTS**
- **Features:** Voice cloning, professional-grade
- **Best For:** Voice cloning, professional applications

---

## Free Cloud TTS Options

### Completely Free & Unlimited (No Credit Card)

#### 1. **Edge-TTS** ⭐ **RECOMMENDED FREE OPTION**

**Overview:**
- Uses Microsoft Edge's online TTS service (unofficial API access)
- **Cost:** 100% FREE, unlimited, no API key required
- **Quality:** Good quality, multiple voices

**Implementation:**
- **Python Library:** `pip install edge-tts`
- **GitHub:**
  - [rany2/edge-tts](https://github.com/rany2/edge-tts) (Original Python)
  - [travisvn/openai-edge-tts](https://github.com/travisvn/openai-edge-tts) (OpenAI-compatible API)
  - [andresayac/edge-tts](https://github.com/andresayac/edge-tts) (Node.js/Bun)

**Features:**
- Works without Edge browser, Windows, or API key
- Many languages and voices
- Outputs MP3, WAV, with optional subtitles (SRT, VTT)
- [Voice samples available](https://tts.travisvn.com/)

**Example Usage:**
```python
import edge_tts
import asyncio

async def generate():
    communicate = edge_tts.Communicate("Hello World", "en-US-AriaNeural")
    await communicate.save("output.wav")

asyncio.run(generate())
```

**⚠️ Commercial Use Caveat:**
- Gray area legally - uses Microsoft's service without official API
- Microsoft recommends Azure AI Speech for commercial applications
- Fine for personal/non-commercial use
- Consider risk tolerance for commercial projects

#### 2. **Puter.js**
- **Cost:** FREE, unlimited
- **Setup:** No API keys, no sign-ups
- **Quality:** Similar to Amazon Polly
- **API:** Simple JavaScript API
- **Best For:** Web-based applications

#### 3. **Vidnoz Text to Speech**
- **Cost:** FREE, no time limit
- **Setup:** No credit card, no subscription
- **Access:** Web-based, immediate
- **Languages:** Multiple supported

### Major Cloud Providers - Free Tiers

#### **Google Cloud Text-to-Speech** ⭐ **BEST FREE TIER**
- **Free Monthly Allowance:**
  - **1 million characters** (WaveNet voices - high quality)
  - **4 million characters** (Standard voices)
- **New Customer Bonus:** $300 credits
- **Voices:** 380+ voices, 75+ languages
- **Quality:** WaveNet = excellent
- **Setup:** Requires Google Cloud account
- **After Free Tier:** Pay-as-you-go pricing

#### **Microsoft Azure Text-to-Speech**
- **Free Tier:** Free (F0) tier with limited usage
- **New Customer Bonus:** $200 credits (~400K characters)
- **Paid Pricing:** $16/1M chars (neural)
- **Features:** Custom Neural Voices available
- **Setup:** Requires Azure account

#### **Amazon Polly**
- **Free Tier:** **5 million chars/month** (first 12 months only)
- **After Year 1:** $4/1M chars
- **Voices:** Neural + standard, 36 languages
- **Setup:** Requires AWS account

#### **ElevenLabs**
- **Free Tier:** ~10,000 chars/month (very limited)
- **Quality:** Best available
- **Note:** Insufficient for production use, good for testing

#### **Fish Audio**
- **Free Tier:** 8,000 monthly credits
- **Self-Hosted:** S1-mini model (Apache 2.0) = unlimited when self-hosted
- **Quality:** Good, emotionally expressive

---

## Open-Source Self-Hosted Options

### 2026 Top Picks (Production-Ready)

#### 1. **Kokoro-82M** ⭐ **LIGHTWEIGHT CHAMPION**

**Overview:**
- **Size:** 82 million parameters (very small)
- **Quality:** Comparable to much larger models
- **Speed:** Significantly faster than competitors
- **License:** Apache 2.0 (commercial use OK)

**Advantages:**
- Minimal hardware requirements
- Fast inference
- Production-ready
- Permissive license

**Best For:**
- Edge deployment
- Low-resource environments
- Quick inference needs

#### 2. **Chatterbox (Resemble AI)** ⭐ **QUALITY WINNER**

**Overview:**
- **Quality:** Beats ElevenLabs in blind tests (63.75% preference)
- **License:** MIT (fully permissive)
- **Speed:** Real-time optimized
- **GPU:** Low requirements

**Advantages:**
- Commercial-quality output
- Production-ready
- Transparent licensing
- Speed + expressiveness

**Best For:**
- High-quality production deployments
- Commercial applications
- Real-time generation

#### 3. **F5-TTS**

**Overview:**
- **License:** MIT
- **Speed:**
  - 7× real-time (standard)
  - 33× real-time (Fast variant)
- **Features:** Zero-shot voice cloning

**Advantages:**
- Very fast inference
- Voice cloning capability
- Permissive license

**Best For:**
- Voice cloning projects
- Speed-critical applications

#### 4. **Piper TTS** (Already in FlowRead!)

**Overview:**
- **License:** MIT
- **Quality:** Most natural-sounding for edge deployment
- **Optimization:** Raspberry Pi, low-resource devices
- **Status:** Actively maintained

**Advantages:**
- Already integrated in your app
- Proven performance
- Community support
- Edge-optimized

#### 5. **FishAudio-S1**

**Overview:**
- **Size:** 4 billion parameters
- **License:** Apache 2.0
- **Features:** Emotional expression, multilingual voice cloning
- **Cloud Option:** 8,000 monthly credits free

**Advantages:**
- Emotional synthesis
- Short reference audio cloning
- Cloud + self-host options

**Best For:**
- Expressive speech
- Voice cloning from minimal samples

#### 6. **Parler-TTS**

**Overview:**
- **License:** Apache 2.0
- **Unique Feature:** Control voice via natural language prompts

**Example Prompts:**
- "A woman speaks in a calm, soothing voice"
- "An excited man with a British accent"

**Best For:**
- Dynamic voice generation
- Creative applications

#### 7. **Qwen3-TTS**

**Overview:**
- **Released:** January 2026 (very new!)
- **License:** Apache 2.0
- **Quality:** Strong performance

**Status:** Cutting-edge, actively developed

### Legacy/Community-Maintained

#### 8. **XTTS-v2 (Coqui TTS)**

**Overview:**
- **Original Creator:** Coqui.ai (company shut down early 2024)
- **Status:** Community-maintained
- **License:** Coqui Public Model License ⚠️ **Non-commercial only**
- **Speed:** <150ms streaming latency

**Advantages:**
- Excellent quality
- 1100+ language support
- Fast streaming

**⚠️ Limitation:** Non-commercial license restricts usage

#### 9. **Bark**

**Overview:**
- **Type:** Generative audio model
- **Reddit Opinion:** "Future of voice synthesis"
- **Features:** Emotional synthesis, multi-speaker

**Note:** Requires more technical setup

#### 10. **VibeVoice (Microsoft)**

**Overview:**
- **Features:** Long-form generation (up to 90 minutes)
- **Speakers:** 4 distinct speakers
- **Best For:** Podcasts, audiobooks, long-form content

---

## Comparison Tables

### Paid APIs - Quick Comparison

| Provider | Latency | Price/1M Chars | Best Feature | Languages |
|----------|---------|----------------|--------------|-----------|
| **Cartesia Sonic 3** | **40ms TTFA** | — | Fastest TTFA | — |
| **Murf Falcon** | 130ms | **$10** | Best price/speed ratio | 35+ |
| **Hume Octave 2** | 100ms | **$7.60** | Cheapest quality option | — |
| **Speechmatics** | 150ms | **$11/1M** | Best value | English (expanding) |
| **ElevenLabs** | 75ms | Higher | Best quality | 70+ |
| **OpenAI TTS** | 200ms | $15/$30 | Best balance | — |
| **Inworld Max** | <250ms | $10 | #1 quality (ELO) | — |
| **Google Cloud** | — | Free tier | Most languages | **75+** |
| **Azure** | — | Free tier | Custom voices | — |
| **Amazon Polly** | — | $4 PAYG | AWS integration | 36 |

### Free Options - Quick Comparison

| Option | Cost | Quality | Commercial OK? | Setup Difficulty | Limitations |
|--------|------|---------|----------------|------------------|-------------|
| **Edge-TTS** | FREE | Good | ⚠️ Gray area | Easy (Python) | Unofficial API |
| **Google Cloud** | 1M/mo free | Excellent | ✅ Yes | Easy (API) | Free tier limit |
| **Azure** | Limited free | Excellent | ✅ Yes | Easy (API) | Free tier limit |
| **Amazon Polly** | 5M/mo (1yr) | Very Good | ✅ Yes | Easy (API) | First year only |
| **Puter.js** | FREE | Good | ❓ Unknown | Easy (JS) | Documentation limited |
| **Kokoro-82M** | FREE | Very Good | ✅ Yes | Medium (self-host) | Requires setup |
| **Chatterbox** | FREE | Excellent | ✅ Yes | Medium (self-host) | Requires GPU |
| **F5-TTS** | FREE | Very Good | ✅ Yes | Medium (self-host) | Requires setup |
| **Piper** | FREE | Good | ✅ Yes | Easy | Already in app! |

### Open-Source Models - Detailed Comparison

| Model | License | Quality | Speed | Voice Cloning | Commercial | Status |
|-------|---------|---------|-------|---------------|------------|--------|
| **Chatterbox** | MIT | ⭐⭐⭐⭐⭐ | Real-time | ✅ | ✅ | Production |
| **Kokoro-82M** | Apache 2.0 | ⭐⭐⭐⭐ | Very Fast | ❌ | ✅ | Production |
| **F5-TTS** | MIT | ⭐⭐⭐⭐ | 7-33× RT | ✅ Zero-shot | ✅ | Production |
| **FishAudio-S1** | Apache 2.0 | ⭐⭐⭐⭐ | Fast | ✅ Emotional | ✅ | Production |
| **Piper** | MIT | ⭐⭐⭐ | Fast | ❌ | ✅ | Production |
| **Parler-TTS** | Apache 2.0 | ⭐⭐⭐ | Medium | Prompt-based | ✅ | Production |
| **Qwen3-TTS** | Apache 2.0 | ⭐⭐⭐⭐ | Fast | ❓ | ✅ | New (2026) |
| **XTTS-v2** | Coqui Public | ⭐⭐⭐⭐ | <150ms | ✅ | ❌ | Community |
| **VibeVoice** | ❓ | ⭐⭐⭐⭐ | Medium | Multi-speaker | ❓ | Research |

---

## Implementation Recommendations

### For FlowRead - Priority Ranking

#### **Tier 1: Easy Wins (Minimal Effort, High Value)**

1. **Edge-TTS** ⭐ **HIGHEST PRIORITY**
   - **Effort:** Low (similar to Groq implementation)
   - **Value:** Unlimited free TTS
   - **Implementation:**
     - Install: `pip install edge-tts`
     - Create `EdgeTTSService.swift` (model after `GroqTTSService.swift`)
     - Call via subprocess like `piper_phonemizer.py`
   - **Risk:** Commercial use gray area (acceptable for many use cases)
   - **Timeline:** 1-2 hours

2. **Google Cloud TTS**
   - **Effort:** Low (REST API, similar to Groq)
   - **Value:** 1M chars/month free, excellent quality
   - **Implementation:**
     - API key setup
     - Create `GoogleTTSService.swift`
     - HTTP requests to Google Cloud endpoint
   - **Risk:** None (official API)
   - **Timeline:** 2-3 hours

3. **OpenAI TTS**
   - **Effort:** Low (well-documented API)
   - **Value:** Industry standard, reliable
   - **Implementation:**
     - API key setup
     - Create `OpenAITTSService.swift`
     - Standard HTTP API calls
   - **Cost:** $15/1M chars (reasonable)
   - **Timeline:** 2-3 hours

#### **Tier 2: Medium Effort, High Value**

4. **Kokoro-82M** (Self-hosted)
   - **Effort:** Medium (model setup, inference server)
   - **Value:** Unlimited free, high quality, lightweight
   - **Implementation:**
     - Set up local inference server
     - Create service similar to Piper
     - May need simple Python/FastAPI wrapper
   - **Timeline:** 4-6 hours

5. **Azure TTS**
   - **Effort:** Low-Medium
   - **Value:** Free tier + custom voice capability
   - **Implementation:** Similar to Google Cloud
   - **Timeline:** 2-3 hours

#### **Tier 3: Advanced Features**

6. **Chatterbox** (Self-hosted)
   - **Effort:** Medium-High (GPU setup, model deployment)
   - **Value:** Best quality, beats commercial APIs
   - **Requirements:** GPU for optimal performance
   - **Timeline:** 6-8 hours

7. **ElevenLabs**
   - **Effort:** Low (standard API)
   - **Value:** Best quality available
   - **Cost:** Higher than others
   - **Use Case:** Premium quality option
   - **Timeline:** 2-3 hours

8. **Cartesia Sonic 3**
   - **Effort:** Low (API integration)
   - **Value:** Ultra-low latency (40ms)
   - **Use Case:** Real-time reading with minimal delay
   - **Timeline:** 2-3 hours

### Recommended Roadmap

**Phase 1: Free Options (Week 1)**
- ✅ Add Edge-TTS service (Day 1-2)
- ✅ Add Google Cloud TTS (Day 3-4)
- ✅ Update UI to show 5 TTS engines
- ✅ Test and validate

**Phase 2: Premium Options (Week 2)**
- Add OpenAI TTS (Day 1)
- Add Azure TTS (Day 2)
- Add ElevenLabs (premium tier) (Day 3)
- UI polish and testing (Day 4-5)

**Phase 3: Self-Hosted (Week 3+)**
- Research Kokoro-82M deployment
- Set up local inference server
- Integrate as local option
- Consider Chatterbox for premium self-hosted

### Architecture Recommendations

#### Service Structure
```
TTSManager.swift (orchestrator)
├── PiperTTSService.swift ✅ (existing)
├── GroqTTSService.swift ✅ (existing)
├── NativeTTSService.swift ✅ (existing)
├── EdgeTTSService.swift ⭐ NEW
├── GoogleTTSService.swift ⭐ NEW
├── OpenAITTSService.swift ⭐ NEW
├── AzureTTSService.swift (optional)
├── ElevenLabsService.swift (optional)
└── KokoroTTSService.swift (future)
```

#### Configuration Strategy

**Unified Config File:** `~/.flowread/tts_config.json`
```json
{
  "api_keys": {
    "groq": ["key1", "key2", "key3"],
    "google_cloud": "key",
    "openai": "key",
    "azure": "key",
    "elevenlabs": "key"
  },
  "default_engine": "piper",
  "fallback_chain": ["piper", "edge-tts", "native"],
  "engines": {
    "edge-tts": {
      "enabled": true,
      "default_voice": "en-US-AriaNeural"
    },
    "google": {
      "enabled": true,
      "default_voice": "en-US-Neural2-A"
    }
  }
}
```

#### Error Handling Strategy

1. **Primary Engine Fails** → Try fallback chain
2. **API Rate Limit** → Rotate to next engine
3. **Network Error** → Fall back to local (Piper/Native)
4. **All Engines Fail** → Show user-friendly error

---

## Technical Integration Notes

### Edge-TTS Integration Pattern

**File Structure:**
```
FlowRead/Services/
├── edge_tts.py (new - bundled script)
├── EdgeTTSService.swift (new)
└── piper_phonemizer.py (existing)
```

**edge_tts.py** (minimal wrapper):
```python
#!/usr/bin/env python3
import edge_tts
import asyncio
import sys
import json

async def generate(text, voice):
    try:
        communicate = edge_tts.Communicate(text, voice)
        output_file = "/tmp/edge_tts_output.wav"
        await communicate.save(output_file)
        return {"success": True, "file": output_file}
    except Exception as e:
        return {"success": False, "error": str(e)}

if __name__ == "__main__":
    text = sys.argv[1]
    voice = sys.argv[2] if len(sys.argv) > 2 else "en-US-AriaNeural"
    result = asyncio.run(generate(text, voice))
    print(json.dumps(result))
```

**EdgeTTSService.swift** (high-level structure):
```swift
actor EdgeTTSService {
    private let pythonPath = "/usr/bin/python3"
    private var scriptPath: String?

    func synthesize(text: String, voice: EdgeVoice) async throws -> Data {
        // 1. Locate edge_tts.py script
        // 2. Chunk text if needed
        // 3. Call Python script via Process
        // 4. Parse JSON response
        // 5. Read WAV file
        // 6. Return audio data
    }
}

enum EdgeVoice: String, CaseIterable {
    case ariaNeural = "en-US-AriaNeural"
    case guyNeural = "en-US-GuyNeural"
    case janeNeural = "en-US-JaneNeural"
    // Add more voices...
}
```

### Google Cloud TTS Integration

**GoogleTTSService.swift** (high-level):
```swift
actor GoogleTTSService {
    private let endpoint = "https://texttospeech.googleapis.com/v1/text:synthesize"
    private var apiKey: String

    func synthesize(text: String, voice: GoogleVoice) async throws -> Data {
        let request = [
            "input": ["text": text],
            "voice": [
                "languageCode": voice.languageCode,
                "name": voice.name
            ],
            "audioConfig": [
                "audioEncoding": "LINEAR16",
                "sampleRateHertz": 22050
            ]
        ]

        // POST to Google Cloud API
        // Parse base64 audio from response
        // Return WAV data
    }
}
```

### Service Protocol Pattern

**Unified interface:**
```swift
protocol TTSService {
    associatedtype Voice: TTSVoice

    func synthesize(text: String, voice: Voice) async throws -> Data
    func availableVoices() -> [Voice]
    func isAvailable() async -> Bool
}

protocol TTSVoice {
    var displayName: String { get }
    var languageCode: String { get }
    var gender: VoiceGender { get }
}
```

### Python Dependency Management

**Current Approach:**
- System Python 3 (`/usr/bin/python3`)
- User installs dependencies manually

**For Edge-TTS:**
```bash
pip3 install edge-tts
```

**Alternative: Bundled Python Environment**
- Consider bundling Python 3.11+ with app
- Include dependencies in app bundle
- More reliable, no user setup required
- Larger app size (~50-100MB additional)

---

## Cost Analysis

### Monthly Usage Scenarios

**Light User (100K characters/month):**
- Google Cloud: **FREE** (within 1M tier)
- Azure: **FREE** (within free tier)
- Edge-TTS: **FREE**
- OpenAI: $1.50
- ElevenLabs: $10+ (exceeds free tier)

**Medium User (5M characters/month):**
- Google Cloud: **FREE** (1M free + $10 for 4M standard voices)
- Edge-TTS: **FREE**
- Amazon Polly: **FREE** (year 1), then $20/month
- OpenAI: $75
- ElevenLabs: $50-100+

**Heavy User (50M characters/month):**
- Edge-TTS: **FREE**
- Kokoro-82M (self-hosted): **FREE** (hosting costs only)
- Google Cloud: ~$100-200 (mix of free + paid)
- OpenAI: $750
- ElevenLabs: $500+

### ROI of Self-Hosting

**Kokoro-82M or Chatterbox Setup:**
- One-time setup: 4-8 hours
- Hosting: $0 (local) or $20-50/month (cloud VPS)
- **Break-even:** After 1M+ chars/month vs paid APIs

---

## Sources

### Paid TTS APIs
- [Best TTS APIs in 2026: Top 12 Text-to-Speech services](https://www.speechmatics.com/company/articles-and-news/best-tts-apis-in-2025-top-12-text-to-speech-services-for-developers)
- [Gladia - Best TTS APIs for Developers in 2026](https://www.gladia.io/blog/best-tts-apis-for-developers-in-2026-top-7-text-to-speech-services)
- [Best TTS APIs for Real-Time Voice Agents (2026 Benchmarks)](https://inworld.ai/resources/best-voice-ai-tts-apis-for-real-time-voice-agents-2026-benchmarks)
- [Best Text-to-Speech APIs (TTS API) Comparison](https://unrealspeech.com/compare)
- [ElevenLabs vs OpenAI TTS Comparison](https://vapi.ai/blog/elevenlabs-vs-openai)

### Free TTS Options
- [Free, Unlimited Text-to-Speech API](https://developer.puter.com/tutorials/free-unlimited-text-to-speech-api/)
- [Best Free Text-to-Speech AI APIs in 2026](https://www.camb.ai/blog-post/best-free-text-to-speech-ai-apis)
- [Google Cloud Text-to-Speech](https://cloud.google.com/text-to-speech)

### Edge-TTS
- [GitHub - edge-tts Python (rany2)](https://github.com/rany2/edge-tts)
- [GitHub - OpenAI-compatible edge-tts (travisvn)](https://github.com/travisvn/openai-edge-tts)
- [Edge TTS Voice Samples](https://tts.travisvn.com/)
- [How I Used Edge-TTS to Build a Free Online Text-to-Speech Site](https://dev.to/alixwang/how-i-used-edge-tts-to-build-a-free-online-text-to-speech-site-47n9)

### Open-Source TTS
- [The Best Open-Source Text-to-Speech Models in 2026](https://bentoml.com/blog/exploring-the-world-of-open-source-text-to-speech-models)
- [Top Open Source TTS Alternatives Compared](https://smallest.ai/blog/open-source-tts-alternatives-compared)
- [Best ElevenLabs Alternatives 2026: Open-Source TTS Comparison](https://ocdevel.com/blog/20250720-tts)
- [Best Open-Source AI Voice Models (2025)](https://nerdynav.com/open-source-ai-voice/)
- [Text to Speech Open Source: 21 Best Projects 2026 Guide](https://qcall.ai/text-to-speech-open-source)

### Real-Time/Low Latency
- [Real-Time TTS API for Low-Latency Streaming](https://www.respeecher.com/real-time-tts-api)
- [Cartesia Sonic-3 Real-time TTS](https://cartesia.ai/sonic)
- [Murf Falcon - Fastest TTS for Voice Agents](https://murf.ai/falcon)

---

**Report Generated:** 2026-02-01
**FlowRead Version:** 1.0.0
**Next Steps:** Implement Edge-TTS as highest priority free option
