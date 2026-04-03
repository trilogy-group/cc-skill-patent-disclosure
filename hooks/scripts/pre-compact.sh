#!/usr/bin/env bash
# Pre-compaction hook — save beads context before conversation is compressed
# This ensures patent disclosure progress survives context compaction

if command -v bd &> /dev/null && [ -d ".beads" ]; then
  bd prime 2>/dev/null || true
fi
