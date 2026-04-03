#!/usr/bin/env bash
# Patent Disclosure Skill — Installation Script
# Run this once to set up all dependencies.

set -euo pipefail

echo "=== Patent Disclosure Skill — Setup ==="

# 1. Install beads if not present
if command -v bd &> /dev/null; then
    echo "[OK] beads (bd) is already installed: $(bd --version 2>/dev/null || echo 'unknown version')"
else
    echo "[INSTALLING] beads (bd) — workflow management for AI agents..."
    curl -fsSL https://raw.githubusercontent.com/gastownhall/beads/main/scripts/install.sh | bash
    echo "[OK] beads installed"
fi

# 2. Install pandoc if not present (needed for docx export)
if command -v pandoc &> /dev/null; then
    echo "[OK] pandoc is already installed"
else
    echo "[INFO] pandoc is not installed. It's needed to export disclosures to .docx"
    echo "       Install with: brew install pandoc"
fi

# 3. Set up beads Claude Code integration
if [ -d ".beads" ]; then
    echo "[OK] beads already initialized in this project"
else
    echo "[INIT] Initializing beads in this project..."
    bd init --quiet
    echo "[OK] beads initialized"
fi

# 4. Set up Claude Code hooks for beads
echo "[SETUP] Configuring Claude Code hooks for beads..."
bd setup claude 2>/dev/null || echo "[WARN] Could not run 'bd setup claude' — you may need to set up hooks manually"

# 5. Create patent-disclosures output directory
mkdir -p patent-disclosures
echo "[OK] patent-disclosures/ directory ready"

echo ""
echo "=== Setup Complete ==="
echo "Run /patent-disclosure to get started."
