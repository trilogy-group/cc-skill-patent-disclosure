#!/usr/bin/env bash
# Patent Disclosure Plugin — Optional Setup
# Run this to install beads for cross-session workflow tracking.
# The plugin works without beads (using file-based state), but beads adds
# richer task management and context survival across conversation compaction.

set -euo pipefail

echo "=== Patent Disclosure Plugin — Setup ==="

# 1. Install beads if not present
if command -v bd &> /dev/null; then
    echo "[OK] beads (bd) is already installed: $(bd --version 2>/dev/null || echo 'version unknown')"
else
    echo ""
    echo "beads (bd) is not installed. beads provides cross-session workflow"
    echo "tracking and survives conversation compaction."
    echo ""
    echo "The plugin works fine without it (uses file-based state instead)."
    echo ""
    read -p "Install beads now? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "[INSTALLING] beads..."
        curl -fsSL https://raw.githubusercontent.com/gastownhall/beads/main/scripts/install.sh | bash
        if command -v bd &> /dev/null; then
            echo "[OK] beads installed successfully"
        else
            echo "[WARN] beads installation may have failed. The plugin will use file-based state."
            echo "       To install manually: curl -fsSL https://raw.githubusercontent.com/gastownhall/beads/main/scripts/install.sh | bash"
        fi
    else
        echo "[SKIP] beads not installed — plugin will use file-based state tracking"
    fi
fi

# 2. Check for pandoc (needed for docx export)
if command -v pandoc &> /dev/null; then
    echo "[OK] pandoc is available for document export"
else
    echo "[INFO] pandoc not found — needed to export disclosures to .docx"
    echo "       Install with: brew install pandoc"
fi

# 3. Create output directory
mkdir -p patent-disclosures
echo "[OK] patent-disclosures/ directory ready"

echo ""
echo "=== Setup Complete ==="
echo "Use /patent-disclosure in any project to get started."
