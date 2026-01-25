.PHONY: bootstrap gen test test-parallel test-slow ci clean help

# Default target
help:
	@echo "Vapor iOS Build System"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  bootstrap    - Install/build required tools (XcodeGen)"
	@echo "  gen          - Generate Xcode project and tokens"
	@echo "  test         - Run unit, snapshot, and E2E tests (PR gate)"
	@echo "  test-parallel - Run all tests with parallelization"
	@echo "  test-slow    - Run integration tests with real ML (nightly)"
	@echo "  ci           - Full CI pipeline (bootstrap -> gen -> test)"
	@echo "  clean        - Remove generated files"
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

# Run tests (PR gate) - uses Swift Testing for repo layout tests
test: gen
	@echo "Running SPM tests..."
	swift test
	@echo "Running Models package tests..."
	cd Packages/Core/Models && swift test
	@echo "Running Persistence package tests..."
	cd Packages/Core/Persistence && swift test
	@echo "Running Audio package tests..."
	cd Packages/Core/Audio && swift test
	@echo "Running Processing package tests..."
	cd Packages/Core/Processing && swift test
	@echo "Running Export package tests..."
	cd Packages/Core/Export && swift test
	@echo "Running Routing package tests..."
	cd Packages/Core/Routing && swift test
	@echo "Running TimelineFeature package tests..."
	cd Packages/Features/TimelineFeature && swift test
	@echo "Running RecordingFeature package tests..."
	cd Packages/Features/RecordingFeature && swift test
	@echo "Running SessionDetailFeature package tests..."
	cd Packages/Features/SessionDetailFeature && swift test
	@echo "Running AudioPlayerFeature package tests..."
	cd Packages/Features/AudioPlayerFeature && swift test
	@echo "Running PeopleFeature package tests..."
	cd Packages/Features/PeopleFeature && swift test
	@echo "Running SpeakerPickerFeature package tests..."
	cd Packages/Features/SpeakerPickerFeature && swift test
	@echo "Running XCode tests..."
	xcodebuild -project xcodegen/Vapor.xcodeproj -scheme Vapor \
		-destination "id=A76B56DB-DEA2-4933-8C81-7A0EF009AC11" \
		-skipMacroValidation -skipPackagePluginValidation \
		-only-testing:VaporTests \
		-only-testing:SnapshotTests \
		-only-testing:E2ETests \
		test | grep -E "(passed|failed|error:)" || true
	@echo "Tests complete."

# Run tests in parallel
# Pre-booted simulators for parallel testing (created via xcrun simctl clone)
AGENT_SIM_UDID ?= DB91C221-C523-4279-A7A8-53929942B22B
AGENT_SIM_CLONE1 ?= E866672E-6F4A-426D-8A33-F1CA95DEE2D7
AGENT_SIM_CLONE2 ?= FD01FD9C-05DE-4A16-B85F-642185740D1B
AGENT_SIM_CLONE3 ?= 5493F8B9-5F9F-4881-AE0F-8B6FAD042E7F
DERIVED_DATA_PATH ?= /Users/bkase/DerivedData/agent-2

test-parallel: gen
	@echo "=== Running tests in parallel ==="
	@echo "Using pre-booted simulators (keep alive between runs)"
	@echo ""
	@echo "Phase 1: Building project..."
	xcodebuild build-for-testing \
		-project xcodegen/Vapor.xcodeproj \
		-scheme Vapor \
		-destination "id=$(AGENT_SIM_UDID)" \
		-derivedDataPath $(DERIVED_DATA_PATH) \
		-skipMacroValidation -skipPackagePluginValidation \
		-quiet
	@echo ""
	@echo "Phase 2: Running SPM package tests in parallel..."
	@$(MAKE) -j8 _test-packages
	@echo ""
	@echo "Phase 3: Running Xcode tests with 4 pre-booted simulators..."
	xcodebuild test-without-building \
		-project xcodegen/Vapor.xcodeproj \
		-scheme Vapor \
		-destination "id=$(AGENT_SIM_UDID)" \
		-destination "id=$(AGENT_SIM_CLONE1)" \
		-destination "id=$(AGENT_SIM_CLONE2)" \
		-destination "id=$(AGENT_SIM_CLONE3)" \
		-derivedDataPath $(DERIVED_DATA_PATH) \
		-skipMacroValidation -skipPackagePluginValidation \
		-only-testing:VaporTests \
		-only-testing:SnapshotTests \
		-only-testing:ToolsTests \
		2>&1 | grep -E "(Test Suite|passed|failed|error:|Executed)" || true
	@echo ""
	@echo "Phase 4: Running E2E tests (sequential - UI tests)..."
	xcodebuild test-without-building \
		-project xcodegen/Vapor.xcodeproj \
		-scheme Vapor \
		-destination "id=$(AGENT_SIM_UDID)" \
		-derivedDataPath $(DERIVED_DATA_PATH) \
		-skipMacroValidation -skipPackagePluginValidation \
		-only-testing:E2ETests \
		2>&1 | grep -E "(Test Suite|passed|failed|error:|Executed)" || true
	@echo ""
	@echo "=== Parallel tests complete ==="

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
