"""Fetch exact approved Kenney archives, copy selected CC0 clips and make one original swoosh.

Uses only Python's standard library. Run from any directory; the output remains
inside Assets/Audio and download caches remain inside .work/audio_sources.
"""
from pathlib import Path
from urllib.request import urlopen
from zipfile import ZipFile
import array
import hashlib
import json
import math
import random
import wave

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "Assets" / "Audio"
CACHE = ROOT / ".work" / "audio_sources"
PACKS = {
    "impact": {
        "title": "Impact Sounds 1.0",
        "page": "https://kenney.nl/assets/impact-sounds",
        "url": "https://kenney.nl/media/pages/assets/impact-sounds/87b4ddecda-1677589768/kenney_impact-sounds.zip",
        "sha256": "029d734af1582474edf3a694d1b0cebc97c1c152f2f39fa34d4c2bafc5de77f8",
    },
    "ui": {
        "title": "UI Audio 1.0",
        "page": "https://kenney.nl/assets/ui-audio",
        "url": "https://kenney.nl/media/pages/assets/ui-audio/490d233f68-1677590494/kenney_ui-audio.zip",
        "sha256": "946fc23a63d535d693eb31b2eabb80c8c28d6351e2186b344ceb71b2cb1d5eb6",
    },
}
SELECTION = {
    "hit_1.ogg": ("impact", "Audio/impactPunch_medium_000.ogg"),
    "hit_2.ogg": ("impact", "Audio/impactPunch_medium_002.ogg"),
    "heavy_1.ogg": ("impact", "Audio/impactPunch_heavy_000.ogg"),
    "heavy_2.ogg": ("impact", "Audio/impactPunch_heavy_002.ogg"),
    "block_1.ogg": ("impact", "Audio/impactMetal_medium_000.ogg"),
    "block_2.ogg": ("impact", "Audio/impactMetal_light_001.ogg"),
    "parry.ogg": ("impact", "Audio/impactMetal_light_004.ogg"),
    "hurt.ogg": ("impact", "Audio/impactSoft_heavy_000.ogg"),
    "step_1.ogg": ("impact", "Audio/footstep_concrete_000.ogg"),
    "step_2.ogg": ("impact", "Audio/footstep_concrete_001.ogg"),
    "ui.ogg": ("ui", "Audio/click3.ogg"),
}


def digest(data):
    return hashlib.sha256(data).hexdigest()


def original_swing(path):
    # Short filtered-noise air movement. No speech, tune, or third-party sample.
    rate, duration = 22050, 0.17
    rng = random.Random(352203)
    samples = array.array("h")
    low = 0.0
    for i in range(int(rate * duration)):
        t = i / rate
        envelope = math.sin(math.pi * t / duration) ** 1.8
        noise = rng.uniform(-1, 1)
        low = 0.64 * low + 0.36 * noise
        value = (noise - low) * envelope * 0.36
        samples.append(int(max(-1, min(1, value)) * 32767))
    import sys
    if sys.byteorder != "little":
        samples.byteswap()
    with wave.open(str(path), "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(rate)
        out.writeframes(samples.tobytes())


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    CACHE.mkdir(parents=True, exist_ok=True)
    archives = {}
    for key, pack in PACKS.items():
        target = CACHE / f"{key}.zip"
        existing = ROOT / ".work" / "report" / "audio_sources" / f"{key}.zip"
        if not target.exists():
            if existing.exists() and digest(existing.read_bytes()) == pack["sha256"]:
                target.write_bytes(existing.read_bytes())
            else:
                with urlopen(pack["url"], timeout=45) as response:
                    target.write_bytes(response.read())
        data = target.read_bytes()
        if digest(data) != pack["sha256"]:
            raise ValueError(f"Source archive checksum changed: {key}")
        archives[key] = ZipFile(target)
        (OUTPUT / f"LICENSE_Kenney_{key}.txt").write_bytes(archives[key].read("License.txt"))
    records = []
    for filename, (pack_key, original) in SELECTION.items():
        data = archives[pack_key].read(original)
        (OUTPUT / filename).write_bytes(data)
        records.append({"file": filename, "pack": pack_key, "source_file": original,
                        "sha256": digest(data), "license": "CC0-1.0", "modified": False})
    original_swing(OUTPUT / "swing.wav")
    records.append({"file": "swing.wav", "source": "Original seeded filtered-noise synthesis in tools/build_audio.py",
                    "sha256": digest((OUTPUT / "swing.wav").read_bytes()), "license": "project-original", "duration_seconds": 0.17})
    manifest = {"retrieved_date": "2026-09-23", "creator": "Kenney", "packs": PACKS,
                "audio_files": records, "runtime_adjustments": "Godot gain and subtle pitch variation; parry pitch 1.5x; source samples otherwise unchanged"}
    (OUTPUT / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    lines = ["# Audio credits", "", "Selected combat and interface effects by Kenney, licensed CC0 1.0.",
             "", "- Impact Sounds 1.0: https://kenney.nl/assets/impact-sounds", "- UI Audio 1.0: https://kenney.nl/assets/ui-audio",
             "- License: https://creativecommons.org/publicdomain/zero/1.0/", "", "Original archive license files are included next to these credits.",
             "Archive URLs, SHA-256 values and per-file provenance are recorded in manifest.json.", "",
             "| Game file | Original pack file |", "| --- | --- |"]
    for filename, (pack_key, original) in SELECTION.items():
        lines.append(f"| {filename} | {PACKS[pack_key]['title']}: {original} |")
    lines += ["", "swing.wav is an original 0.17-second filtered-noise swoosh generated by tools/build_audio.py.",
              "It contains no external samples or music. Source OGG clips are copied unchanged; the game adjusts gain and pitch during playback.",
              "", "The audio manager uses at most eight simultaneous voices and stops combat effects on pause or return to menus.",
              "No music or speech is downloaded or streamed at runtime.", ""]
    (OUTPUT / "ASSET_CREDITS.md").write_text("\n".join(lines), encoding="utf-8")
    for archive in archives.values():
        archive.close()
    print(json.dumps({"output": str(OUTPUT), "effects": len(records), "audio_bytes": sum((OUTPUT / x['file']).stat().st_size for x in records)}, indent=2))


if __name__ == "__main__":
    main()
