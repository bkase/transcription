"""Run the same native XCUITest workload against the two release builds."""
import argparse
import csv
import json
import plistlib
import re
import shutil
import statistics
import subprocess
import time
from pathlib import Path

APP = Path(__file__).resolve().parents[2]
SOURCE = Path(__file__).resolve().parent
BUNDLE_IDS = {"Exact": "com.vapor.exact", "Rune": "com.vapor.rune-ios"}
MARK = re.compile(r"VAPOR_BENCH (Exact|Rune) ([\w-]+) ([0-9.]+) ([0-9.]+)")


def sim(udid, *args):
    return subprocess.check_output(["xcrun", "simctl", args[0], udid, *args[1:]], text=True).strip()


def executable(bundle):
    name = plistlib.loads((bundle / "Info.plist").read_bytes())["CFBundleExecutable"]
    return str(bundle / name)


def sample(processes):
    rows = subprocess.check_output(["ps", "-axo", "pid=,rss=,time=,command="], text=True)
    stamp = time.time()
    for row in rows.splitlines():
        pid, rss, cpu, command = row.strip().split(maxsplit=3)
        command = command.replace("/private/tmp/", "/tmp/")
        for framework, path in processes.items():
            if command == path or command.startswith(path + " "):
                yield stamp, framework, int(pid), int(rss), cpu


def cpu_seconds(value):
    seconds = 0.0
    for part in value.split(":"):
        seconds = seconds * 60 + float(part)
    return seconds


def summarize(rows, marks):
    result = {}
    for framework in BUNDLE_IDS:
        series = [row for row in rows if row[1] == framework]
        windows = {}
        grouped = {}
        for name, when, ms in marks.get(framework, []):
            if name.endswith("-start"):
                windows[name[:-6]] = when
            if ms:
                grouped.setdefault(f"{name}_ms", []).append(round(ms, 1))
            if name.endswith("-end"):
                phase = name[:-4]
                if phase not in windows:
                    continue
                inside = [row for row in series if windows[phase] <= row[0] <= when]
                if len(inside) >= 2 and inside[0][2] == inside[-1][2]:
                    grouped.setdefault(f"{phase}_rss_mib", []).append(
                        round(statistics.median(row[3] for row in inside) / 1024, 2))
                    grouped.setdefault(f"{phase}_cpu_pct", []).append(round(
                        100 * (cpu_seconds(inside[-1][4]) - cpu_seconds(inside[0][4]))
                        / (inside[-1][0] - inside[0][0]), 2))
        result[framework] = {
            metric: {"median": round(statistics.median(values), 2), "runs": values}
            for metric, values in grouped.items()
        }
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sim", required=True, help="Booted iOS Simulator UDID")
    parser.add_argument("--exact", type=Path, required=True, help="Exact release .app")
    parser.add_argument("--rune", type=Path, required=True, help="Rune release .app")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--launch-only", action="store_true")
    args = parser.parse_args()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    if (out / "Comparison.xcresult").exists():
        parser.error("Choose a fresh output directory.")
    build = APP / ".exact" / "benchmark"
    build.mkdir(parents=True, exist_ok=True)
    for file in ("project.yml", "ComparisonTests.swift"):
        shutil.copy2(SOURCE / file, build / file)
    subprocess.run(["xcodegen", "generate", "--spec", str(build / "project.yml")], check=True)
    processes = {}
    for framework, source in (("Exact", args.exact), ("Rune", args.rune)):
        sim(args.sim, "install", str(source.resolve(strict=True)))
        bundle_id = BUNDLE_IDS[framework]
        sim(args.sim, "privacy", "grant", "microphone", bundle_id)
        processes[framework] = executable(Path(sim(args.sim, "get_app_container", bundle_id, "app")))
    scheme = "VaporComparisonIOS"
    command = ["xcodebuild", "test", "-project", str(build / "VaporComparison.xcodeproj"),
               "-scheme", scheme, "-derivedDataPath", str(build / "build-ios"),
               "-destination", f"id={args.sim}", "-resultBundlePath", str(out / "Comparison.xcresult"),
               "-parallel-testing-enabled", "NO", "-collect-test-diagnostics", "never",
               "CODE_SIGNING_ALLOWED=NO", "ONLY_ACTIVE_ARCH=YES"]
    if args.launch_only:
        command.append(f"-only-testing:{scheme}/ComparisonTests/testALaunches()")
    rows = []
    with (out / "xctest.log").open("w") as log:
        process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT)
        while process.poll() is None:
            rows.extend(sample(processes))
            time.sleep(0.20)
    marks = {}
    for framework, phase, stamp, ms in MARK.findall((out / "xctest.log").read_text()):
        marks.setdefault(framework, []).append((phase, float(stamp), float(ms)))
    with (out / "samples.csv").open("w") as file:
        writer = csv.writer(file)
        writer.writerow(["unix_seconds", "framework", "pid", "rss_kib", "cpu_time"])
        writer.writerows(rows)
    metrics = json.dumps(summarize(rows, marks), indent=2) + "\n"
    (out / "metrics.json").write_text(metrics)
    print(metrics, end="")
    return process.returncode


if __name__ == "__main__":
    raise SystemExit(main())
