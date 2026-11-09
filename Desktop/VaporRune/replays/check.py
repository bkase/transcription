#!/usr/bin/env python3
"""Exercise the native Rune controls with its offscreen renderer and virtual clock."""

import json
import os
from pathlib import Path
import subprocess
import sys
from tempfile import TemporaryDirectory
import wave

APP = Path(__file__).resolve().parents[1]
BINARY = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else APP / "target/debug/vapor-rune"
FLOW = "record-save-play.json"


def run(output, name, script=None, mark=None, data=None, png=False):
    target = output / (name + ".json")
    args = [str(BINARY), "--tree", str(target), "--theme", "light", "--scale", "2"]
    if png:
        args += ["--snap", str(target.with_suffix(".png"))]
    if script:
        args += ["--script", str(APP / "replays" / script)]
    if mark:
        args += ["--at", f"mark:{mark}"]
    env = dict(os.environ, VAPOR_RUNE_DATA_DIR=str(data or output / name))
    result = subprocess.run(args, env=env, capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError(result.stderr)
    tree = json.loads(target.read_text())
    assert not tree["warnings"], tree["warnings"]
    return {node["key"]: node for node in tree["elements"] if node.get("key")}


def main():
    with TemporaryDirectory(prefix="vapor-rune-check-") as temp:
        output = Path(temp)
        entering = run(output, "entering", FLOW, "sheet-in")
        recording = run(output, "recording", FLOW, "recording")
        assert 0 < entering["recording"]["opacity"] < 1
        assert entering["recording"]["rect"][1] > recording["recording"]["rect"][1]
        assert recording["recordingStatus"]["text"] == "RECORDING"
        assert not recording["stopAndSaveButton"]["focusable"]

        paused = run(output, "paused", FLOW, "paused", png=True)
        repeated = run(output, "paused-again", FLOW, "paused", png=True)
        assert paused == repeated
        assert (output / "paused.png").read_bytes() == (output / "paused-again.png").read_bytes()
        later = run(output, "paused-later", FLOW, "paused-later")
        assert paused["recordingStatus"]["text"] == "PAUSED"
        assert paused["recordingTimer"]["text"] == later["recordingTimer"]["text"] == "00:01"
        assert paused["recordingDot"]["scale"] != recording["recordingDot"]["scale"]

        opening = run(output, "opening", FLOW, "setup-opening")
        opened = run(output, "opened", FLOW, "setup-open")
        closed_y = paused["speakerSetup"]["rect"][1]
        open_y = opened["speakerSetup"]["rect"][1]
        assert open_y < opening["speakerSetup"]["rect"][1] < closed_y
        ready = run(output, "ready", FLOW, "ready-to-save")
        assert ready["speakerRow0"]["label"] == "Alex"
        assert ready["speakerCount2"]["fill"] == "#a0c4e8ff"
        assert ready["stopAndSaveButton"]["focusable"]

        playing = run(output, "playing", FLOW, "playing")
        assert playing["playbackButton"]["label"] == "Pause playback"
        assert playing["playbackTime"]["text"] == "0:01"
        data = output / "saved-data"
        finished = run(output, "finished", FLOW, "end", data)
        assert finished["playbackButton"]["label"] == "Play recording"
        assert finished["playbackTime"]["text"] == "0:01"
        (metadata,) = data.glob("*/session.json")
        session = json.loads(metadata.read_text())
        assert session["speakers"] == ["Alex", "Speaker 2"]
        with wave.open(str(metadata.with_name(session["audio"])), "rb") as audio:
            assert audio.getnchannels() == 1
            assert abs(audio.getnframes() / audio.getframerate() - session["duration"]) < 0.02
            assert 3.0 < session["duration"] < 4.0, session["duration"]
            assert any(audio.readframes(audio.getnframes()))
        restored = run(output, "restored", data=data)
        assert restored[f"session-{session['id']}"]["label"] == "Untitled Recording"

        canceled = run(output, "canceled", "discard.json", "still-recording")
        assert canceled["recordingStatus"]["text"] == "RECORDING"
        discarded = run(output, "discarded", "discard.json", "end")
        assert "startRecordingButton" in discarded
        assert not any((output / "discarded").iterdir())

    print("Vapor replays passed: sheet and drawer motion, repeatable pixels, pause/resume, "
          "speaker naming, saved WAV, playback, relaunch, and discard.")


if __name__ == "__main__":
    main()
