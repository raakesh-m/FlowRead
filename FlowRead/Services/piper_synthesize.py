#!/usr/bin/env python3
"""
piper_synthesize.py - Piper TTS Synthesis Script for FlowRead
Synthesizes text to speech using piper-tts and outputs WAV audio
This allows FlowRead to be lightweight while still having full offline TTS
"""

import sys
import os
import json
import tempfile
import struct

def main():
    if len(sys.argv) < 3:
        print(json.dumps({"error": "Usage: piper_synthesize.py <text> <model_path> [output_path]"}), file=sys.stderr)
        sys.exit(1)
    
    text = sys.argv[1]
    model_path = sys.argv[2]
    output_path = sys.argv[3] if len(sys.argv) > 3 else None
    
    # Try to import piper
    try:
        from piper import PiperVoice
        import wave
        import numpy as np
    except ImportError as e:
        print(json.dumps({
            "error": "piper-tts not installed",
            "details": str(e),
            "fix": "pip3 install --user piper-tts"
        }), file=sys.stderr)
        sys.exit(1)
    
    try:
        # Load the voice model
        config_path = model_path + ".json"
        
        if not os.path.exists(model_path):
            print(json.dumps({"error": f"Model not found: {model_path}"}), file=sys.stderr)
            sys.exit(1)
        
        # Load voice
        voice = PiperVoice.load(model_path, config_path=config_path if os.path.exists(config_path) else None)
        
        # Generate speech
        # PiperVoice.synthesize yields AudioChunk objects
        audio_chunks = []
        sample_rate = 22050  # Default

        for audio_chunk in voice.synthesize(text):
            # Get raw int16 audio bytes from the chunk
            audio_bytes = audio_chunk.audio_int16_array.tobytes()
            audio_chunks.append(audio_bytes)
            # Get sample rate from first chunk
            sample_rate = audio_chunk.sample_rate

        if not audio_chunks:
            print(json.dumps({"error": "No audio generated"}), file=sys.stderr)
            sys.exit(1)

        # Combine all audio chunks
        raw_audio = b''.join(audio_chunks)
        
        # Convert to WAV format
        wav_data = create_wav(raw_audio, sample_rate)
        
        if output_path:
            # Write to file
            with open(output_path, 'wb') as f:
                f.write(wav_data)
            print(json.dumps({
                "success": True,
                "output": output_path,
                "size": len(wav_data),
                "sample_rate": sample_rate
            }))
        else:
            # Write to stdout as base64
            import base64
            audio_b64 = base64.b64encode(wav_data).decode('ascii')
            print(json.dumps({
                "success": True,
                "audio_base64": audio_b64,
                "size": len(wav_data),
                "sample_rate": sample_rate
            }))
            
    except Exception as e:
        print(json.dumps({
            "error": "Synthesis failed",
            "details": str(e)
        }), file=sys.stderr)
        sys.exit(1)

def create_wav(raw_audio: bytes, sample_rate: int) -> bytes:
    """Convert raw int16 PCM audio to WAV format"""
    
    num_channels = 1
    bits_per_sample = 16
    byte_rate = sample_rate * num_channels * bits_per_sample // 8
    block_align = num_channels * bits_per_sample // 8
    data_size = len(raw_audio)
    
    # WAV header
    wav = bytearray()
    
    # RIFF header
    wav.extend(b'RIFF')
    wav.extend(struct.pack('<I', 36 + data_size))  # File size - 8
    wav.extend(b'WAVE')
    
    # fmt chunk
    wav.extend(b'fmt ')
    wav.extend(struct.pack('<I', 16))  # Chunk size
    wav.extend(struct.pack('<H', 1))   # Audio format (PCM)
    wav.extend(struct.pack('<H', num_channels))
    wav.extend(struct.pack('<I', sample_rate))
    wav.extend(struct.pack('<I', byte_rate))
    wav.extend(struct.pack('<H', block_align))
    wav.extend(struct.pack('<H', bits_per_sample))
    
    # data chunk
    wav.extend(b'data')
    wav.extend(struct.pack('<I', data_size))
    wav.extend(raw_audio)
    
    return bytes(wav)

if __name__ == "__main__":
    main()
