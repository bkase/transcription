#!/bin/bash
# Setup isolated iOS Simulator environment for concurrent agent usage
# Usage: ./setup-agent-sim.sh <agent_number>
#
# Each agent gets:
# - Its own simulator device (unique UDID)
# - Its own DerivedData directory
# - Explicit lifecycle control

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

# Create DerivedData directory (idempotent)
mkdir -p "$DERIVED_DATA_PATH"
echo "✓ DerivedData path: $DERIVED_DATA_PATH"

# Check if simulator already exists
EXISTING_UDID=$(xcrun simctl list devices -j | jq -r --arg name "$AGENT_NAME" '
  .devices | to_entries[] | .value[] | select(.name == $name) | .udid
' | head -1)

if [[ -n "$EXISTING_UDID" ]]; then
  echo "✓ Simulator '$AGENT_NAME' already exists: $EXISTING_UDID"
  UDID="$EXISTING_UDID"
else
  # Find latest iOS runtime
  RUNTIME=$(xcrun simctl list runtimes -j | jq -r '
    .runtimes | map(select(.name | startswith("iOS"))) | sort_by(.version) | last | .identifier
  ')

  if [[ -z "$RUNTIME" || "$RUNTIME" == "null" ]]; then
    echo "Error: No iOS runtime found"
    exit 1
  fi

  echo "Creating simulator '$AGENT_NAME' with runtime $RUNTIME..."
  UDID=$(xcrun simctl create "$AGENT_NAME" "$DEVICE_TYPE" "$RUNTIME")
  echo "✓ Created simulator: $UDID"
fi

# Output configuration for agent use
CONFIG_FILE="$DERIVED_DATA_PATH/sim-config.env"
cat > "$CONFIG_FILE" << EOF
# Agent $AGENT_NUM Simulator Configuration
# Source this file: source $CONFIG_FILE

export AGENT_SIM_UDID="$UDID"
export AGENT_SIM_NAME="$AGENT_NAME"
export AGENT_DERIVED_DATA="$DERIVED_DATA_PATH"

# Usage with xcodebuild:
# xcodebuild -derivedDataPath "\$AGENT_DERIVED_DATA" -destination "id=\$AGENT_SIM_UDID" test
EOF

echo "✓ Config written to: $CONFIG_FILE"
echo ""
echo "=== Agent $AGENT_NUM Configuration ==="
echo "UDID:        $UDID"
echo "Name:        $AGENT_NAME"
echo "DerivedData: $DERIVED_DATA_PATH"
echo ""
echo "To use: source $CONFIG_FILE"
