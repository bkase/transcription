#!/usr/bin/env python3
"""Run the native simulator hot-reload scenario against a disposable copy of Vapor."""

import argparse
import json
from pathlib import Path
import re
import shutil
import signal
import subprocess
import tempfile
import time
import uuid


APP = Path(__file__).resolve().parents[1]
TEST = "VaporRuneUITests/RecordingTests/testSimulatorHotReloadKeepsRecordingAndRebuildsHandlers()"


def wait_for(log, text, process, timeout):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        contents = log.read_text()
        match = re.search(text, contents)
        if match:
            return match
        if process.poll() is not None:
            raise RuntimeError(contents[-6000:])
        time.sleep(0.1)
    raise TimeoutError(f"{text!r} did not appear in {log}\n{contents[-6000:]}")


def edit(source):
    original = source.read_text()
    replacements = {
        'label("Paused",': 'label("Paused after patch",',
        ".child(content),": '.child(content).child(label("Live Rust patch", 14.0, 400.0, 0.0, "deep")),',
        ".on_press(State::save)": '''.on_press(|s: &mut State| {
            if let Page::Recording(draft) = &mut s.page {
                draft.names[1] = "Hot speaker".into();
            }
            s.save();
        })''',
    }
    edited = original
    for before, after in replacements.items():
        if edited.count(before) != 1:
            raise RuntimeError(f"Update the hot test edit for {before!r}")
        edited = edited.replace(before, after)
    return original, edited


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("launcher", type=Path, help="Rune's scripts/rune-hot")
    parser.add_argument("simulator", help="iOS Simulator UDID")
    parser.add_argument("--derived-data", type=Path, default=APP / "target/ios-hot-tests")
    parser.add_argument("--results", type=Path, default=APP / "target" / f"ios-hot-{uuid.uuid4().hex[:8]}.xcresult")
    args = parser.parse_args()

    project = ["-project", "ios/VaporRune.xcodeproj", "-scheme", "VaporRune",
               "-derivedDataPath", str(args.derived_data.resolve()), "-destination", f"id={args.simulator}"]
    results = args.results.resolve()
    results.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["xcodegen", "generate", "--spec", "ios/project.yml"], cwd=APP, check=True)
    subprocess.run(["xcodebuild", "build-for-testing", *project, "CODE_SIGNING_ALLOWED=NO", "-quiet"],
                   cwd=APP, check=True)

    with tempfile.TemporaryDirectory(prefix="vapor-ios-hot-check-") as tmp:
        tmp = Path(tmp)
        copy = tmp / "VaporRune"
        shutil.copytree(APP, copy, ignore=shutil.ignore_patterns(
            "target", "VaporRune.xcodeproj", "Generated", "__pycache__"))
        source = copy / "src/ui.rs"
        original, edited = edit(source)
        hot_log = tmp / "hot.log"
        test_log = tmp / "test.log"
        with hot_log.open("w") as output:
            hot = subprocess.Popen([
                str(args.launcher.resolve()), "--manifest", str(copy / "Cargo.toml"),
                "--patch", "src/ui.rs", "--ios-simulator", args.simulator, "--sim-microphone",
                "--prepare", "ios/prepare-hot.sh", "--features", "ios-hot", "--",
                "--ui-testing", "--reset-test-archive",
            ], cwd=copy, stdout=output, stderr=subprocess.STDOUT)
        test = None
        try:
            pid = wait_for(hot_log, r"simulator ready \(pid (\d+)\)", hot, 240).group(1)
            with test_log.open("w") as output:
                test = subprocess.Popen([
                    "xcodebuild", "test-without-building", *project, "-parallel-testing-enabled", "NO",
                    "-collect-test-diagnostics", "never", f"-only-testing:{TEST}",
                    "-resultBundlePath", str(results),
                ], cwd=APP, stdout=output, stderr=subprocess.STDOUT)
            wait_for(test_log, 'for "Paused after patch" StaticText to exist', test, 35)
            source.write_text(original.replace('label("Paused",', 'label(,'))
            wait_for(hot_log, "edit not ready", hot, 10)
            source.write_text(edited)
            patch = wait_for(hot_log, rf"simulator presented patch 1 \(pid {pid}, (\d+) ms\)", hot, 45)
            if test.wait(timeout=45):
                raise RuntimeError(test_log.read_text()[-6000:])
            summary = json.loads(subprocess.check_output(
                ["xcrun", "xcresulttool", "get", "test-results", "summary", "--path", str(results)]))
            if summary["passedTests"] != 1 or summary["failedTests"] != 0:
                raise RuntimeError(test_log.read_text()[-6000:])

            source.write_text(original)
            wait_for(hot_log, rf"simulator presented patch 2 \(pid {pid}, \d+ ms\)", hot, 30)
            print(f"Native view and handler patch presented in {patch.group(1)} ms (PID {pid}).")
            print("XCUITest verified that the recording stayed paused, resumed, and saved through the patched handler.")
            print(f"The revert landed in the same process. Test result: {results}")
        finally:
            if test and test.poll() is None:
                test.terminate()
                test.wait(timeout=15)
            if hot.poll() is None:
                hot.send_signal(signal.SIGINT)
                hot.wait(timeout=20)


if __name__ == "__main__":
    main()
