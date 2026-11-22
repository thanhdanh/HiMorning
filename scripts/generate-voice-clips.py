#!/usr/bin/env python3
"""
Pre-generate natural neural TTS voice clips (.m4a AAC) for HiMorning VoiceCoach
and Read Aloud spoken examples using Microsoft Edge Neural TTS
(vi-VN-HoaiMyNeural and en-US-AvaNeural).

Usage:
  /opt/homebrew/bin/python3 -m venv /tmp/tts-venv
  /tmp/tts-venv/bin/pip install edge-tts
  /tmp/tts-venv/bin/python3 scripts/generate-voice-clips.py
"""

import asyncio
import hashlib
import json
import os
import re
import subprocess
import tempfile
from pathlib import Path
import edge_tts
from gtts import gTTS

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "apps" / "ios" / "Resources" / "Voice"

VOICES = {
    "vi": "vi-VN-HoaiMyNeural",
    "en": "en-US-AvaNeural",
}

VOICE_COACH_KEYS = [
    # Initial spoken movement cues
    "Lower yourself, then push up.",
    "Wave your hand side to side.",
    "Turn your head to each side, then back to the middle.",
    "Open your arms and legs, then bring them together.",
    "Raise both arms to count one.",
    "Point your camera toward a bright window or lamp.",
    "Arms down, up, then down.",
    "Bend your knees, then stand up.",
    # Framing & live hints
    "Step back so your whole body fits.",
    "Show your feet in the camera.",
    "Keep both shoulders and elbows in view.",
    "Come a little closer.",
    "Stand where the camera can see you.",
    "Move slowly up and down, within the camera view.",
    "Keep your body straight in a push-up position, with your whole body in view.",
    "Place your phone so your whole body is visible.",
    "The view is unclear. Try moving your phone.",
    "The movement is unclear. Try moving your phone.",
    "Place your hand in view and wave it side to side.",
    "Raise both arms to count one. Lower them before raising them again.",
    "Keep your whole body visible and move through the jumping jack.",
    "Stand sideways in view, bend your knees gently, then stand again.",
    "Stay seated and move both arms down, up, then down.",
    "Keep your whole body in view.",
    "Keep your upper body and both wrists in view.",
    "Move smoothly and follow the rhythm.",
    "The pose is unclear. Try again slowly.",
    # Completion & status phrases
    "Push-ups complete.",
    "Guided rhythm completed.",
    "Rhythm complete.",
    "Challenge completed",
    "Movement detected.",
    "Movement checked.",
    "Great reading.",
    "Correct. Challenge completed!",
    "Morning light checked.",
    "You confirmed you are awake.",
]


def load_localizable(locale: str) -> dict[str, str]:
    path = ROOT / "apps" / "ios" / "Resources" / f"{locale}.lproj" / "Localizable.strings"
    mapping: dict[str, str] = {}
    pattern = re.compile(r'^("(?:[^"\\]|\\.)*")\s*=\s*("(?:[^"\\]|\\.)*");$')
    for line in path.read_text(encoding="utf-8").splitlines():
        s = line.strip()
        if not s or s.startswith("//"):
            continue
        m = pattern.match(s)
        if m:
            mapping[json.loads(m.group(1))] = json.loads(m.group(2))
    return mapping


def clip_filename(lang: str, text: str) -> str:
    digest = hashlib.sha256(f"{lang}:{text.strip()}".encode("utf-8")).hexdigest()[:16]
    return f"voice_{lang}_{digest}.m4a"


def _save_gtts(text: str, lang: str, out_mp3: Path):
    tld = "com.vn" if lang == "vi" else "com"
    gTTS(text=text, lang=lang, tld=tld, slow=False).save(str(out_mp3))


async def synthesize_one(sem: asyncio.Semaphore, lang: str, text: str, out_path: Path):
    if out_path.exists() and out_path.stat().st_size > 200:
        return
    voice = VOICES[lang]
    async with sem:
        with tempfile.NamedTemporaryFile(suffix=".mp3", delete=False) as tmp:
            tmp_mp3 = Path(tmp.name)
        try:
            try:
                communicate = edge_tts.Communicate(text, voice)
                await communicate.save(str(tmp_mp3))
            except Exception:
                await asyncio.to_thread(_save_gtts, text, lang, tmp_mp3)
            subprocess.run(
                [
                    "/usr/bin/afconvert",
                    "-f",
                    "m4af",
                    "-d",
                    "aac",
                    "-b",
                    "32000",
                    str(tmp_mp3),
                    str(out_path),
                ],
                check=True,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
        finally:
            tmp_mp3.unlink(missing_ok=True)


async def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    en_strings = load_localizable("en")
    vi_strings = load_localizable("vi")

    phrases: list[tuple[str, str]] = []
    for key in VOICE_COACH_KEYS:
        if key in en_strings:
            phrases.append(("en", en_strings[key]))
        if key in vi_strings:
            phrases.append(("vi", vi_strings[key]))

    # Milestone numbers 5..50
    for count in range(5, 55, 5):
        phrases.append(("en", str(count)))
        phrases.append(("vi", str(count)))

    # Read Aloud passages (all 36 English passages)
    read_aloud_path = ROOT / "shared" / "content" / "challenges" / "read-aloud.en.json"
    for item in json.loads(read_aloud_path.read_text(encoding="utf-8")):
        phrases.append(("en", item["text"]))

    # UI test fixture readAloud sentence
    phrases.append(("en", "Small steps create steady progress."))

    # Deduplicate while preserving deterministic order
    seen: set[tuple[str, str]] = set()
    unique_phrases: list[tuple[str, str]] = []
    for item in phrases:
        norm = (item[0], item[1].strip())
        if norm not in seen:
            seen.add(norm)
            unique_phrases.append(norm)

    print(f"Generating {len(unique_phrases)} neural voice clips into {OUT_DIR}...")
    sem = asyncio.Semaphore(4)
    tasks = []
    expected_files: set[str] = set()
    for lang, text in unique_phrases:
        fname = clip_filename(lang, text)
        expected_files.add(fname)
        tasks.append(synthesize_one(sem, lang, text, OUT_DIR / fname))

    await asyncio.gather(*tasks)

    # Remove stale clips not in expected_files
    for existing in OUT_DIR.glob("voice_*.m4a"):
        if existing.name not in expected_files:
            existing.unlink()

    total_kb = sum(f.stat().st_size for f in OUT_DIR.glob("voice_*.m4a")) / 1024.0
    print(f"Done! {len(expected_files)} neural clips ready ({total_kb:.1f} KB total).")


if __name__ == "__main__":
    asyncio.run(main())
