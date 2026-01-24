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
	@echo "Generating Xcode project..."
	cd xcodegen && xcodegen generate
	@echo "Project generated at xcodegen/Vapor.xcodeproj"

# Run tests (PR gate) - uses Swift Testing for repo layout tests
test: gen
	@echo "Running tests..."
	swift test
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
