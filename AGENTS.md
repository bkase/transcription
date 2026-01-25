## Agent 1 Simulator Configuration

```
UDID:        A76B56DB-DEA2-4933-8C81-7A0EF009AC11
Name:        Agent-1-iPhone
DerivedData: /Users/bkase/DerivedData/agent-1
```

**CRITICAL: Always run simulators HEADLESS. Never use `open` or `activate` Simulator.app.**

**Usage:**

```bash
# Source environment
source /Users/bkase/DerivedData/agent-1/sim-config.env

# Boot headless (no GUI)
xcrun simctl boot A76B56DB-DEA2-4933-8C81-7A0EF009AC11
xcrun simctl bootstatus A76B56DB-DEA2-4933-8C81-7A0EF009AC11 -b  # Wait for boot

# Build and run
xcodebuild -project <project> -scheme <app-target> \
  -derivedDataPath /Users/bkase/DerivedData/agent-1 \
  -destination "id=A76B56DB-DEA2-4933-8C81-7A0EF009AC11" \
  -skipMacroValidation -skipPackagePluginValidation build

# Install and launch
xcrun simctl install A76B56DB-DEA2-4933-8C81-7A0EF009AC11 /Users/bkase/DerivedData/agent-1/Build/Products/Debug-iphonesimulator/<app-name>
xcrun simctl launch A76B56DB-DEA2-4933-8C81-7A0EF009AC11 <app-slug>

# Take screenshots (headless)
xcrun simctl io A76B56DB-DEA2-4933-8C81-7A0EF009AC11 screenshot output.png

# UI Testing (headless) - use XCUITest
xcodebuild test -project <project> -scheme <test-target> \
  -derivedDataPath /Users/bkase/DerivedData/agent-1 \
  -destination "id=A76B56DB-DEA2-4933-8C81-7A0EF009AC11"
```

**For UI flow verification, use XCUITest - never GUI automation tools.**

<!-- br-agent-instructions-v1 -->

---

## Beads Workflow Integration

This project uses [beads_rust](https://github.com/Dicklesworthstone/beads_rust) (`br`/`bd`) for issue tracking. Issues are stored in `.beads/` and tracked in git.

### Essential Commands

```bash
# View ready issues (unblocked, not deferred)
br ready              # or: bd ready

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
