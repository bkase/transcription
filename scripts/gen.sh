#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "Generating Xcode project..."
cd "$PROJECT_ROOT/xcodegen"
xcodegen generate

echo "Project generated successfully."
