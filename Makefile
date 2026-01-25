.PHONY: bootstrap gen test test-slow ci clean help

# Default target
help:
	@echo "Vapor iOS Build System"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  bootstrap    - Install/build required tools (XcodeGen)"
	@echo "  gen          - Generate Xcode project and tokens"
	@echo "  test         - Run all tests with parallel execution (PR gate)"
	@echo "  test-slow    - Run integration tests with real ML (nightly)"
	@echo "  ci           - Full CI pipeline (bootstrap -> gen -> test)"
	@echo "  clean        - Remove generated files"
	@echo ""
	@echo "Before running tests, source your simulator config:"
	@echo "  source ~/DerivedData/agent-N/sim-config.env && make test"
	@echo ""

# Build pinned tools
bootstrap:
	@echo "Checking for XcodeGen..."
	@command -v xcodegen >/dev/null 2>&1 || { echo "Installing XcodeGen..."; brew install xcodegen; }
	@echo "Bootstrap complete."

# Generate Xcode project and tokens
gen: bootstrap
	@echo "Building tools..."
	cd tools && swift build
	@echo "Running TokenGen..."
	cd tools && swift run TokenGen --input ../tokens.json --output ../Packages/Core/DesignSystem/Sources/DesignSystem/Generated/DesignTokens.swift
	@echo "Running DocGen..."
	cd tools && swift run DocGen --input ../Packages/Core/Persistence/Sources/Persistence --output ../docs/schema
	@echo "Generating Xcode project..."
	cd xcodegen && xcodegen generate
	@echo "Preserving Package.resolved..."
	@mkdir -p xcodegen/Vapor.xcodeproj/project.xcworkspace/xcshareddata/swiftpm
	@cp xcodegen/Package.resolved xcodegen/Vapor.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
	@echo "Project generated at xcodegen/Vapor.xcodeproj"

# Run tests with parallel execution (PR gate)
# Simulators are configured via scripts/setup-agent-sim.sh which creates:
# - Main simulator + 3 clones for parallel testing
# - Config file at ~/DerivedData/agent-N/sim-config.env
#
# Usage: source ~/DerivedData/agent-N/sim-config.env && make test
#
# Env vars (set by sim-config.env or override manually):
AGENT_SIM_UDID ?= $(error AGENT_SIM_UDID not set - source sim-config.env first)
AGENT_SIM_CLONE1 ?= $(error AGENT_SIM_CLONE1 not set - source sim-config.env first)
AGENT_SIM_CLONE2 ?= $(error AGENT_SIM_CLONE2 not set - source sim-config.env first)
AGENT_SIM_CLONE3 ?= $(error AGENT_SIM_CLONE3 not set - source sim-config.env first)
AGENT_DERIVED_DATA ?= $(error AGENT_DERIVED_DATA not set - source sim-config.env first)

test:
	@uv run scripts/run-tests.py

# Internal target for parallel package testing
_test-packages: _test-models _test-persistence _test-audio _test-export _test-routing _test-designsystem \
                _test-timeline _test-recording _test-sessiondetail _test-audioplayer _test-people _test-speakerpicker

_test-models:
	@cd Packages/Core/Models && swift test --quiet 2>&1 | tail -5

_test-persistence:
	@cd Packages/Core/Persistence && swift test --quiet 2>&1 | tail -5

_test-audio:
	@cd Packages/Core/Audio && swift test --quiet 2>&1 | tail -5

_test-export:
	@cd Packages/Core/Export && swift test --quiet 2>&1 | tail -5

_test-routing:
	@cd Packages/Core/Routing && swift test --quiet 2>&1 | tail -5

_test-designsystem:
	@cd Packages/Core/DesignSystem && swift test --quiet 2>&1 | tail -5

_test-timeline:
	@cd Packages/Features/TimelineFeature && swift test --quiet 2>&1 | tail -5

_test-recording:
	@cd Packages/Features/RecordingFeature && swift test --quiet 2>&1 | tail -5

_test-sessiondetail:
	@cd Packages/Features/SessionDetailFeature && swift test --quiet 2>&1 | tail -5

_test-audioplayer:
	@cd Packages/Features/AudioPlayerFeature && swift test --quiet 2>&1 | tail -5

_test-people:
	@cd Packages/Features/PeopleFeature && swift test --quiet 2>&1 | tail -5

_test-speakerpicker:
	@cd Packages/Features/SpeakerPickerFeature && swift test --quiet 2>&1 | tail -5

# Run slow integration tests (nightly)
test-slow: gen
	@echo "Running slow integration tests with FluidAudio ML models..."
	RUN_SLOW_TESTS=1 swift test --filter FluidAudioIntegration
	@echo "Slow tests complete."

# Full CI pipeline
ci: bootstrap gen test
	@echo "CI pipeline complete."

# Clean generated files
clean:
	@echo "Cleaning..."
	rm -rf xcodegen/Vapor.xcodeproj
	rm -rf build/
	rm -rf .build/
	@echo "Clean complete."
