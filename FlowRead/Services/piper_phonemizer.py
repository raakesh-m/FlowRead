#!/usr/bin/env python3
"""
Piper Phonemizer Helper
Converts text to phoneme IDs using espeak-ng for Piper TTS models.
"""

import sys
import json
from pathlib import Path

# Try to import from installed piper-tts package
try:
    from piper.phonemize_espeak import EspeakPhonemizer
    from piper.phoneme_ids import phonemes_to_ids
except ImportError:
    print(json.dumps({
        "error": "piper-tts not installed. Run: pip3 install piper-tts"
    }), file=sys.stderr)
    sys.exit(1)


def phonemize_text(text: str, voice: str = "en-us") -> list[int]:
    """
    Convert text to phoneme IDs for Piper TTS.

    Args:
        text: Input text to phonemize
        voice: eSpeak voice (default: en-us)

    Returns:
        List of phoneme IDs
    """
    try:
        # Initialize phonemizer
        phonemizer = EspeakPhonemizer()

        # Get phonemes (returns list of lists for sentences)
        phoneme_lists = phonemizer.phonemize(voice, text)

        # Flatten all sentences into one list
        all_phonemes = []
        for sentence_phonemes in phoneme_lists:
            all_phonemes.extend(sentence_phonemes)

        # Convert phonemes to IDs
        phoneme_ids = phonemes_to_ids(all_phonemes)

        return phoneme_ids

    except Exception as e:
        raise RuntimeError(f"Phonemization failed: {e}")


def main():
    """Command-line interface."""
    if len(sys.argv) < 2:
        print(json.dumps({
            "error": "Usage: piper_phonemizer.py <text> [voice]"
        }), file=sys.stderr)
        sys.exit(1)

    text = sys.argv[1]
    voice = sys.argv[2] if len(sys.argv) > 2 else "en-us"

    try:
        phoneme_ids = phonemize_text(text, voice)

        # Output as JSON
        result = {
            "success": True,
            "text": text,
            "voice": voice,
            "phoneme_ids": phoneme_ids,
            "count": len(phoneme_ids)
        }

        print(json.dumps(result))
        sys.exit(0)

    except Exception as e:
        print(json.dumps({
            "error": str(e),
            "success": False
        }), file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
