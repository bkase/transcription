## Agent 2 Simulator Configuration

```
UDID:        DB91C221-C523-4279-A7A8-53929942B22B
Name:        Agent-2-iPhone
DerivedData: /Users/bkase/DerivedData/agent-2

Parallel Testing Clones:
  Clone 1:   E866672E-6F4A-426D-8A33-F1CA95DEE2D7  (Agent-2-Clone-1)
  Clone 2:   FD01FD9C-05DE-4A16-B85F-642185740D1B  (Agent-2-Clone-2)
  Clone 3:   5493F8B9-5F9F-4881-AE0F-8B6FAD042E7F  (Agent-2-Clone-3)
```

**CRITICAL: Always run simulators HEADLESS. Never use `open` or `activate` Simulator.app.**

**Usage:**

```bash
# Source environment
source /Users/bkase/DerivedData/agent-2/sim-config.env

# Boot all simulators (main + clones)
xcrun simctl boot DB91C221-C523-4279-A7A8-53929942B22B
xcrun simctl boot E866672E-6F4A-426D-8A33-F1CA95DEE2D7
xcrun simctl boot FD01FD9C-05DE-4A16-B85F-642185740D1B
xcrun simctl boot 5493F8B9-5F9F-4881-AE0F-8B6FAD042E7F

# Build and run
xcodebuild -project <project> -scheme <app-target> \
  -derivedDataPath /Users/bkase/DerivedData/agent-2 \
  -destination "id=DB91C221-C523-4279-A7A8-53929942B22B" \
  -skipMacroValidation -skipPackagePluginValidation build

# Run tests with parallel execution (4 simulators)
xcodebuild test-without-building -project <project> -scheme <test-target> \
  -destination "id=DB91C221-C523-4279-A7A8-53929942B22B" \
  -destination "id=E866672E-6F4A-426D-8A33-F1CA95DEE2D7" \
  -destination "id=FD01FD9C-05DE-4A16-B85F-642185740D1B" \
  -destination "id=5493F8B9-5F9F-4881-AE0F-8B6FAD042E7F" \
  -derivedDataPath /Users/bkase/DerivedData/agent-2

# Take screenshots (headless)
xcrun simctl io DB91C221-C523-4279-A7A8-53929942B22B screenshot output.png

# UI Testing (headless, single sim for E2E)
xcodebuild test -project <project> -scheme <test-target> \
  -derivedDataPath /Users/bkase/DerivedData/agent-2 \
  -destination "id=DB91C221-C523-4279-A7A8-53929942B22B"
```

**For UI flow verification, use XCUITest - never GUI automation tools.**

- Don't run the full test suite manually, it's run automatically when you commit. You can just run the particular tests that you think are affected by your change.

---

## Beads Workflow Integration

This project uses [beads_rust](https://github.com/Dicklesworthstone/beads_rust) (`br`) for issue tracking. Issues are stored in `.beads/` and tracked in git.

### Essential Commands

```bash
# View ready issues (unblocked, not deferred)
br ready              # or: br ready

# List and search
br list --status=open # All open issues
br show <id>          # Full issue details with dependencies
br search "keyword"   # Full-text search

# Create and update
br create --title="..." --type=task --priority=2
br update <id> --status=in_progress
br close <id> --reason="Completed"
br close <id1> <id2>  # Close multiple issues at once

# Sync with git
br sync --flush-only  # Export DB to JSONL
br sync --status      # Check sync status
```

### Workflow Pattern

1. **Start**: Run `br ready` to find actionable work
2. **Claim**: Use `br update <id> --status=in_progress`
3. **Work**: Implement the task
4. **Complete**: Use `br close <id>`
5. **Sync**: Always run `br sync --flush-only` at session end

### Key Concepts

- **Dependencies**: Issues can block other issues. `br ready` shows only unblocked work.
- **Priority**: P0=critical, P1=high, P2=medium, P3=low, P4=backlog (use numbers 0-4, not words)
- **Types**: task, bug, feature, epic, question, docs
- **Blocking**: `br dep add <issue> <depends-on>` to add dependencies

### Session Protocol

**Before ending any session, run this checklist:**

```bash
git status              # Check what changed
git add <files>         # Stage code changes
br sync --flush-only    # Export beads changes to JSONL
git commit -m "..."     # Commit everything
git push                # Push to remote
```

### Best Practices

- Check `br ready` at session start to find available work
- Update status as you work (in_progress → closed)
- Create new issues with `br create` when you discover tasks
- Use descriptive titles and set appropriate priority/type
- Always sync before ending session

<!-- end-br-agent-instructions -->
