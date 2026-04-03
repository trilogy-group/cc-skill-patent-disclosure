#!/usr/bin/env bash
# Session start hook — load beads context if available
# This runs at the start of every Claude Code session

# Only run if beads is installed and initialized in this project
if command -v bd &> /dev/null && [ -d ".beads" ]; then
  # Check for in-progress patent disclosure tasks
  ACTIVE=$(bd list --status in_progress --json 2>/dev/null | grep -c "Patent\|Invention\|Disclosure" || true)
  if [ "$ACTIVE" -gt 0 ]; then
    echo "Patent disclosure work in progress. Use /patent-disclosure to resume."
    bd prime 2>/dev/null || true
  fi
fi
