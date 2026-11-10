"""Verify Exact's simulator live reload while recording is paused."""
import argparse
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

tools = Path(__file__).resolve().parent
app = tools.parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("simulator")
parser.add_argument("bundle", type=Path)
parser.add_argument("output", type=Path)
parser.add_argument("--url", default="http://127.0.0.1:18765/")
args = parser.parse_args()
output = args.output.resolve()
output.mkdir(parents=True, exist_ok=False)
build = app / ".exact" / "benchmark"
build.mkdir(parents=True, exist_ok=True)
for name in ("project.yml", "ComparisonTests.swift"):
    shutil.copy2(tools / "bench" / name, build / name)
subprocess.run(["xcodegen", "generate", "--spec", str(build / "project.yml")], check=True)
command = [
    "xcodebuild", "-project", str(build / "VaporComparison.xcodeproj"),
    "-scheme", "VaporComparisonIOS", "-derivedDataPath", str(build / "build-ios"),
    "-destination", f"id={args.simulator}", "-parallel-testing-enabled", "NO",
    "-collect-test-diagnostics", "never", "CODE_SIGNING_ALLOWED=NO",
]
with (output / "build.log").open("w") as build_log:
    subprocess.run([*command, "build-for-testing"], stdout=build_log, stderr=subprocess.STDOUT, check=True)

source = app / "app.contract"
original = source.read_text()
data = app / "app.ts"
original_data = data.read_text()
view = 'isPaused ? "Paused" : isLive'
handler = "keepTake(takeId, media.path, media.duration, names.slice(0, count))"
assert original.count(view) == original.count(handler) == 1
edited = original.replace(view, 'isPaused ? "Paused after edit" : isLive').replace(
    handler, 'keepTake(takeId, media.path, media.duration, ["Hot Speaker"].concat(names.slice(1, count)))').replace(
    'text "Timeline" font-size=28', 'text "Timeline after edit" font-size=28')
edited_data = original_data.replace('"Untitled Recording"', '"Updated Recording"')
assert edited_data != original_data
subprocess.run(["xcrun", "simctl", "terminate", args.simulator, "com.vapor.exact"], capture_output=True)
app_log = (output / "app.log").open("w")
carrier = subprocess.Popen([
    sys.executable, str(tools / "hot-ios.py"), args.simulator, str(args.bundle),
    "--url", args.url, "--grant-microphone", "--console",
], stdout=app_log, stderr=subprocess.STDOUT)
listing = ["xcrun", "simctl", "spawn", args.simulator, "launchctl", "list"]
app_label = re.compile(r"^(\d+)\s+[^\s]+\s+UIKitApplication:com\.vapor\.exact\[", re.MULTILINE)
deadline = time.monotonic() + 20
while time.monotonic() < deadline:
    match = app_label.search(subprocess.check_output(listing, text=True))
    if match and carrier.poll() is None:
        pid = int(match[1])
        break
    time.sleep(0.2)
else:
    carrier.terminate()
    app_log.close()
    raise RuntimeError(f"Exact did not launch. See {output / 'app.log'}")
log = output / "xctest.log"
edited_at = None
restored = False
with log.open("w") as file:
    run = subprocess.Popen([
        *command, "test-without-building", "-resultBundlePath", str(output / "Hot.xcresult"),
        "-only-testing:VaporComparisonIOS/ComparisonTests/testExactHotRecording()",
    ], stdout=file, stderr=subprocess.STDOUT, env={**os.environ, "TEST_RUNNER_VAPOR_HOT_CHECK": "1"})
    try:
        deadline = time.monotonic() + 150
        while run.poll() is None:
            if time.monotonic() >= deadline:
                raise TimeoutError(f"Hot reload check timed out. See {log}")
            checks = log.read_text()
            if edited_at is None and "VAPOR_HOT paused " in checks:
                source.write_text(original + "\ncomponent\n")
                time.sleep(1)
                edited_at = time.time()
                source.write_text(edited)
                data.write_text(edited_data)
            if not restored and "VAPOR_HOT saved " in checks:
                source.write_text(original)
                data.write_text(original_data)
                restored = True
            time.sleep(0.075)
        if run.returncode:
            raise RuntimeError(f"XCUITest failed. See {log}")
        assert edited_at is not None, f"The recording never paused. See {log}"
        checks = log.read_text()
        presented = float(re.search(r"VAPOR_HOT presented ([\d.]+)", checks)[1])
        assert restored, f"The recording was never saved through the live edit. See {log}"
        os.kill(pid, 0)
        print(f"Exact presented the new view after {(presented - edited_at) * 1000:.0f} ms in PID {pid}.")
    finally:
        if carrier.poll() is None:
            carrier.terminate()
        app_log.close()
        if run.poll() is None:
            run.terminate()
            run.wait(timeout=15)
        if not restored:
            source.write_text(original)
            data.write_text(original_data)
