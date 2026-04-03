#!/usr/bin/env bash
# Session start hook — check for in-progress patent disclosure work
# This runs at the start of every Claude Code session

# Check file-based state (always works, no external dependencies)
if [ -f "patent-disclosures/.state.json" ]; then
  # Check if any inventions are in_progress
  if grep -q '"in_progress"' patent-disclosures/.state.json 2>/dev/null; then
    echo "Patent disclosure work in progress. Use /patent-disclosure to resume."
  fi
fi

# Also check beads if available
if command -v bd &> /dev/null && [ -d ".beads" ]; then
  bd prime 2>/dev/null || true
fi
