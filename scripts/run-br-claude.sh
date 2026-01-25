#!/bin/bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

if [ ! -f "learnings.txt" ]; then
  touch "learnings.txt"
fi

PROMPT=$(
  cat <<PROMPT
1. Take the next bead, \`br ready --json\`; and read \`learnings.txt\`
2. complete the work, make sure tests pass and ensure any new builds/tests are added to the pre-commit hook
  Note: No "manual qa" allowed, you must make everything automated, you can use sim XCUITest with accessibility hooks to tap around to do qa non-manually. Make sure the XCUITest run quickly, no sleeps allowed.
3. commit when its working
4. Remember anything you learned to \`learnings.txt\`, but be concise
Do not pick up a new task, just stop when you are done
PROMPT
)

max_iterations=250
iteration=0

while true; do
  iteration=$((iteration + 1))
  if [ "$iteration" -gt "$max_iterations" ]; then
    echo "Reached max iterations ($max_iterations). Exiting."
    exit 0
  fi
  echo "Iteration $iteration/$max_iterations"
  ready_json="$(br ready --json)"
  ready_count=$(printf "%s" "$ready_json" | python3 -c "import json,sys; data=json.load(sys.stdin); print(len(data))")

  if [ "$ready_count" -eq 0 ]; then
    echo "No ready beads. Exiting."
    exit 0
  fi

  echo "Found $ready_count ready bead(s). Running claude code..."
  echo "$PROMPT" | claude -p --dangerously-skip-permissions --verbose --output-format=text
  sleep 3

done
