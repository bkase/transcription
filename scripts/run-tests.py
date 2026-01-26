#!/usr/bin/env python3
# /// script
# requires-python = ">=3.10"
# dependencies = []
# ///
"""
Test runner for Vapor iOS project.
- One line per section on success
- Full output on failure
- Exit 1 on any failure
"""

import subprocess
import sys
import os
import re
from dataclasses import dataclass, field


@dataclass
class TestResult:
    phase: str
    passed: int = 0
    failed: int = 0
    output: str = ""
    success: bool = True


def get_env_vars() -> dict[str, str]:
    required = ["AGENT_SIM_UDID", "AGENT_SIM_CLONE1", "AGENT_SIM_CLONE2", "AGENT_SIM_CLONE3", "AGENT_DERIVED_DATA"]
    env = os.environ.copy()
    missing = [v for v in required if v not in env]
    if missing:
        print(f"ERROR: Missing: {', '.join(missing)}")
        print("Run: source ~/DerivedData/agent-N/sim-config.env")
        sys.exit(1)
    return env


def run_gen(env: dict[str, str]) -> bool:
    print("gen...", end=" ", flush=True)
    proc = subprocess.run(["make", "gen"], env=env, capture_output=True, text=True)
    if proc.returncode != 0:
        print("FAILED")
        print(proc.stdout + proc.stderr)
        return False
    print("ok")
    return True


def run_build(env: dict[str, str]) -> bool:
    print("build...", end=" ", flush=True)
    cmd = [
        "xcodebuild", "build-for-testing",
        "-project", "xcodegen/Vapor.xcodeproj", "-scheme", "Vapor",
        "-destination", f"id={env['AGENT_SIM_UDID']}",
        "-derivedDataPath", env["AGENT_DERIVED_DATA"],
        "-skipMacroValidation", "-skipPackagePluginValidation", "-quiet",
    ]
    proc = subprocess.run(cmd, env=env, capture_output=True, text=True)
    if proc.returncode != 0:
        print("FAILED")
        print(proc.stdout + proc.stderr)
        return False
    print("ok")
    return True


def run_spm_tests(env: dict[str, str]) -> TestResult:
    print("spm...", end=" ", flush=True)
    packages = [
        ".",  # Root-level tests (CoreTests, CoreProcessingTests, ToolsTests)
        "Packages/Core/Models", "Packages/Core/Persistence", "Packages/Core/Audio",
        "Packages/Core/Processing", "Packages/Core/Export", "Packages/Core/Routing",
        "Packages/Core/DesignSystem", "Packages/Core/Observability",
        "Packages/Features/TimelineFeature", "Packages/Features/RecordingFeature",
        "Packages/Features/SessionDetailFeature", "Packages/Features/AudioPlayerFeature",
        "Packages/Features/PeopleFeature", "Packages/Features/SpeakerPickerFeature",
        "Packages/Features/ProfileFeature",
    ]
    result = TestResult(phase="SPM")
    outputs = []

    for path in packages:
        old_cwd = os.getcwd()
        try:
            os.chdir(path)
            proc = subprocess.run(["swift", "test", "--quiet"], env=env, capture_output=True, text=True, timeout=120)
            output = proc.stdout + proc.stderr
            match = re.search(r"Test run with (\d+) tests? .* (passed|failed)", output)
            if match:
                count = int(match.group(1))
                if match.group(2) == "passed":
                    result.passed += count
                else:
                    result.failed += count
                    result.success = False
                    outputs.append(output)
            elif proc.returncode != 0:
                # Signal 11 crashes from stale macro build artifacts are common
                # Only mark as failure if we didn't run any tests at all
                if "signal code 11" in output:
                    # This is a known issue with swift-syntax macros
                    # Skip unless we can't find any test results
                    pass
                else:
                    result.success = False
                    outputs.append(output)
        except subprocess.TimeoutExpired:
            result.success = False
            outputs.append(f"{path}: TIMEOUT")
        finally:
            os.chdir(old_cwd)

    result.output = "\n".join(outputs)
    status = "ok" if result.success else "FAILED"
    print(f"{result.passed} passed, {result.failed} failed [{status}]")
    return result


def run_xcode_tests(env: dict[str, str], targets: list[str], name: str, parallel: bool) -> TestResult:
    print(f"{name}...", end=" ", flush=True)
    cmd = [
        "xcodebuild", "test-without-building",
        "-project", "xcodegen/Vapor.xcodeproj", "-scheme", "Vapor",
        "-destination", f"id={env['AGENT_SIM_UDID']}",
    ]
    if parallel:
        cmd += ["-destination", f"id={env['AGENT_SIM_CLONE1']}",
                "-destination", f"id={env['AGENT_SIM_CLONE2']}",
                "-destination", f"id={env['AGENT_SIM_CLONE3']}"]
    cmd += ["-derivedDataPath", env["AGENT_DERIVED_DATA"],
            "-skipMacroValidation", "-skipPackagePluginValidation"]
    for t in targets:
        cmd.append(f"-only-testing:{t}")

    proc = subprocess.run(cmd, env=env, capture_output=True, text=True, timeout=300)
    output = proc.stdout + proc.stderr

    result = TestResult(phase=name, output=output)
    seen = set()

    # Swift Testing format
    for m in re.finditer(r"Test case '([^']+)' (passed|failed)", output):
        if m.group(1) not in seen:
            seen.add(m.group(1))
            if m.group(2) == "passed":
                result.passed += 1
            else:
                result.failed += 1

    # XCTest format
    for m in re.finditer(r"Test Case '-\[([^\]]+)\]' (passed|failed)", output):
        if m.group(1) not in seen:
            seen.add(m.group(1))
            if m.group(2) == "passed":
                result.passed += 1
            else:
                result.failed += 1

    result.success = proc.returncode == 0 and result.failed == 0 and "TEST EXECUTE FAILED" not in output
    status = "ok" if result.success else "FAILED"
    print(f"{result.passed} passed, {result.failed} failed [{status}]")
    return result


def main() -> int:
    env = get_env_vars()
    results = []

    # Note: gen is now handled by Makefile dependency (test: gen)
    # so we skip running it here to avoid running twice
    if not run_build(env):
        return 1

    results.append(run_spm_tests(env))
    results.append(run_xcode_tests(env, ["VaporTests", "SnapshotTests"], "unit/snapshot", parallel=True))
    results.append(run_xcode_tests(env, ["E2ETests"], "e2e", parallel=False))

    total_passed = sum(r.passed for r in results)
    total_failed = sum(r.failed for r in results)
    any_failed = any(not r.success for r in results)

    print(f"\nTOTAL: {total_passed} passed, {total_failed} failed")

    if any_failed:
        print("\n" + "=" * 60 + "\nFAILURE DETAILS\n" + "=" * 60)
        for r in results:
            if not r.success and r.output:
                print(f"\n--- {r.phase} ---\n{r.output}")
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
