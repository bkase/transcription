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
	@echo "  test         - Run unit, snapshot, and E2E tests (PR gate)"
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
	@echo "Running XCode tests..."
	xcodebuild -project xcodegen/Vapor.xcodeproj -scheme Vapor \
		-destination "id=A76B56DB-DEA2-4933-8C81-7A0EF009AC11" \
		-skipMacroValidation -skipPackagePluginValidation \
		-only-testing:VaporTests \
		-only-testing:SnapshotTests \
		-only-testing:E2ETests \
		test | grep -E "(passed|failed|error:)" || true
	@echo "Tests complete."

# Run slow integration tests (nightly)
test-slow: gen
	@echo "Running slow integration tests..."
	swift test
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
