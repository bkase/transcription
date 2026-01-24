#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=== Vapor Generation Pipeline ==="

echo ""
echo "Step 1: Bootstrap"
make -C "$PROJECT_ROOT" bootstrap

echo ""
echo "Step 2: Generate"
make -C "$PROJECT_ROOT" gen

echo ""
echo "=== Generation Complete ==="
