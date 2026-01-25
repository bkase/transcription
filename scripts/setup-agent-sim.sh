#!/bin/bash
# Setup isolated iOS Simulator environment for concurrent agent usage
# Usage: ./setup-agent-sim.sh <agent_number>
#
# Each agent gets:
# - Its own simulator device (unique UDID)
# - 3 clone simulators for parallel testing
# - Its own DerivedData directory
# - Explicit lifecycle control
# - Auto-updated CLAUDE.md with configuration

set -euo pipefail

AGENT_NUM="${1:-}"

if [[ -z "$AGENT_NUM" ]]; then
  echo "Usage: $0 <agent_number>"
  echo "Example: $0 1"
  exit 1
fi

AGENT_NAME="Agent-${AGENT_NUM}-iPhone"
DEVICE_TYPE="iPhone 16 Pro"
DERIVED_DATA_ROOT="$HOME/DerivedData"
DERIVED_DATA_PATH="$DERIVED_DATA_ROOT/agent-${AGENT_NUM}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CLAUDE_MD="$PROJECT_ROOT/CLAUDE.md"

# Create DerivedData directory (idempotent)
mkdir -p "$DERIVED_DATA_PATH"
echo "✓ DerivedData path: $DERIVED_DATA_PATH"

# Helper: get or create simulator
get_or_create_sim() {
  local name="$1"
  local existing_udid
  existing_udid=$(xcrun simctl list devices -j | jq -r --arg name "$name" '
    .devices | to_entries[] | .value[] | select(.name == $name) | .udid
  ' | head -1)

  if [[ -n "$existing_udid" ]]; then
    echo "$existing_udid"
  else
    # Find latest iOS runtime
    local runtime
    runtime=$(xcrun simctl list runtimes -j | jq -r '
      .runtimes | map(select(.name | startswith("iOS"))) | sort_by(.version) | last | .identifier
    ')
    if [[ -z "$runtime" || "$runtime" == "null" ]]; then
      echo "Error: No iOS runtime found" >&2
      exit 1
    fi
    xcrun simctl create "$name" "$DEVICE_TYPE" "$runtime"
  fi
}

# Helper: get or create clone from existing simulator
get_or_create_clone() {
  local clone_name="$1"
  local source_udid="$2"
  local existing_udid
  existing_udid=$(xcrun simctl list devices -j | jq -r --arg name "$clone_name" '
    .devices | to_entries[] | .value[] | select(.name == $name) | .udid
  ' | head -1)

  if [[ -n "$existing_udid" ]]; then
    echo "$existing_udid"
  else
    xcrun simctl clone "$source_udid" "$clone_name"
  fi
}

# Create/get main simulator
echo "Setting up main simulator..."
UDID=$(get_or_create_sim "$AGENT_NAME")
echo "✓ Main simulator '$AGENT_NAME': $UDID"

# Create/get 3 clones for parallel testing
echo "Setting up clone simulators for parallel testing..."
CLONE1_NAME="Agent-${AGENT_NUM}-Clone-1"
CLONE2_NAME="Agent-${AGENT_NUM}-Clone-2"
CLONE3_NAME="Agent-${AGENT_NUM}-Clone-3"

CLONE1_UDID=$(get_or_create_clone "$CLONE1_NAME" "$UDID")
echo "✓ Clone 1 '$CLONE1_NAME': $CLONE1_UDID"

CLONE2_UDID=$(get_or_create_clone "$CLONE2_NAME" "$UDID")
echo "✓ Clone 2 '$CLONE2_NAME': $CLONE2_UDID"

CLONE3_UDID=$(get_or_create_clone "$CLONE3_NAME" "$UDID")
echo "✓ Clone 3 '$CLONE3_NAME': $CLONE3_UDID"

# Boot all simulators
echo "Booting all simulators..."
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl boot "$CLONE1_UDID" 2>/dev/null || true
xcrun simctl boot "$CLONE2_UDID" 2>/dev/null || true
xcrun simctl boot "$CLONE3_UDID" 2>/dev/null || true
echo "✓ All simulators booted"

# Output configuration for agent use
CONFIG_FILE="$DERIVED_DATA_PATH/sim-config.env"
cat > "$CONFIG_FILE" << EOF
# Agent $AGENT_NUM Simulator Configuration
# Source this file: source $CONFIG_FILE

export AGENT_SIM_UDID="$UDID"
export AGENT_SIM_NAME="$AGENT_NAME"
export AGENT_DERIVED_DATA="$DERIVED_DATA_PATH"

# Clone UDIDs for parallel testing
export AGENT_SIM_CLONE1="$CLONE1_UDID"
export AGENT_SIM_CLONE2="$CLONE2_UDID"
export AGENT_SIM_CLONE3="$CLONE3_UDID"

# Usage with xcodebuild (single destination):
# xcodebuild -derivedDataPath "\$AGENT_DERIVED_DATA" -destination "id=\$AGENT_SIM_UDID" test

# Usage with parallel testing (4 destinations):
# xcodebuild test-without-building \\
#   -destination "id=\$AGENT_SIM_UDID" \\
#   -destination "id=\$AGENT_SIM_CLONE1" \\
#   -destination "id=\$AGENT_SIM_CLONE2" \\
#   -destination "id=\$AGENT_SIM_CLONE3" \\
#   -derivedDataPath "\$AGENT_DERIVED_DATA" ...
EOF

echo "✓ Config written to: $CONFIG_FILE"

# Update CLAUDE.md with simulator configuration
echo "Updating CLAUDE.md..."

# Generate the new simulator section
CLAUDE_SIM_SECTION="## Agent $AGENT_NUM Simulator Configuration

\`\`\`
UDID:        $UDID
Name:        $AGENT_NAME
DerivedData: $DERIVED_DATA_PATH

Parallel Testing Clones:
  Clone 1:   $CLONE1_UDID  ($CLONE1_NAME)
  Clone 2:   $CLONE2_UDID  ($CLONE2_NAME)
  Clone 3:   $CLONE3_UDID  ($CLONE3_NAME)
\`\`\`

**CRITICAL: Always run simulators HEADLESS. Never use \`open\` or \`activate\` Simulator.app.**

**Usage:**

\`\`\`bash
# Source environment
source $CONFIG_FILE

# Boot all simulators (main + clones)
xcrun simctl boot $UDID
xcrun simctl boot $CLONE1_UDID
xcrun simctl boot $CLONE2_UDID
xcrun simctl boot $CLONE3_UDID

# Build and run
xcodebuild -project <project> -scheme <app-target> \\
  -derivedDataPath $DERIVED_DATA_PATH \\
  -destination \"id=$UDID\" \\
  -skipMacroValidation -skipPackagePluginValidation build

# Run tests with parallel execution (4 simulators)
xcodebuild test-without-building -project <project> -scheme <test-target> \\
  -destination \"id=$UDID\" \\
  -destination \"id=$CLONE1_UDID\" \\
  -destination \"id=$CLONE2_UDID\" \\
  -destination \"id=$CLONE3_UDID\" \\
  -derivedDataPath $DERIVED_DATA_PATH

# Take screenshots (headless)
xcrun simctl io $UDID screenshot output.png

# UI Testing (headless, single sim for E2E)
xcodebuild test -project <project> -scheme <test-target> \\
  -derivedDataPath $DERIVED_DATA_PATH \\
  -destination \"id=$UDID\"
\`\`\`

**For UI flow verification, use XCUITest - never GUI automation tools.**"

# Check if CLAUDE.md exists and has simulator section
if [[ -f "$CLAUDE_MD" ]]; then
  # Remove old simulator section (from "## Agent N Simulator" to next "---" or "## Beads")
  # Use perl for multi-line replacement
  perl -i -0777 -pe 's/## Agent \d+ Simulator Configuration.*?(?=---|\n## Beads|$)//s' "$CLAUDE_MD"

  # Prepend new section
  TEMP_FILE=$(mktemp)
  echo "$CLAUDE_SIM_SECTION" > "$TEMP_FILE"
  echo "" >> "$TEMP_FILE"
  cat "$CLAUDE_MD" >> "$TEMP_FILE"
  mv "$TEMP_FILE" "$CLAUDE_MD"
else
  echo "$CLAUDE_SIM_SECTION" > "$CLAUDE_MD"
fi

echo "✓ CLAUDE.md updated"

echo ""
echo "=== Agent $AGENT_NUM Configuration ==="
echo "UDID:        $UDID"
echo "Name:        $AGENT_NAME"
echo "DerivedData: $DERIVED_DATA_PATH"
echo ""
echo "Parallel Testing Clones:"
echo "  Clone 1:   $CLONE1_UDID"
echo "  Clone 2:   $CLONE2_UDID"
echo "  Clone 3:   $CLONE3_UDID"
echo ""
echo "To use: source $CONFIG_FILE"
