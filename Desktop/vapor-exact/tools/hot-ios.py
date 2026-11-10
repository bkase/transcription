"""Launch an Exact development build on a simulator without Simulator.app."""
import argparse
import os
import subprocess
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("simulator")
parser.add_argument("bundle", type=Path)
parser.add_argument("--url", default="http://127.0.0.1:18765/")
parser.add_argument("--grant-microphone", action="store_true")
parser.add_argument("--console", action="store_true")
args = parser.parse_args()

def sim(action, *arguments):
    subprocess.run(["xcrun", "simctl", action, args.simulator, *arguments], check=True)

sim("bootstatus", "-b")
sim("install", str(args.bundle.resolve(strict=True)))
if args.grant_microphone:
    sim("privacy", "grant", "microphone", "com.vapor.exact")
redirect = ["--console"] if args.console else []
os.execvpe(
    "xcrun",
    ["xcrun", "simctl", "launch", "--terminate-running-process", *redirect, args.simulator, "com.vapor.exact"],
    {**os.environ, "SIMCTL_CHILD_EXACT_DEV_PLAN": args.url},
)
