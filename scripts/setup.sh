#!/usr/bin/env bash
# Patent Disclosure Plugin — Post-Install Setup
# Runs automatically after `claude plugin install patent-disclosure`

set -euo pipefail

echo "=== Patent Disclosure Plugin — Setup ==="

# 1. Install beads if not present
if command -v bd &> /dev/null; then
    echo "[OK] beads (bd) is already installed"
else
    echo "[INSTALLING] beads — workflow management for cross-session persistence..."
    curl -fsSL https://raw.githubusercontent.com/gastownhall/beads/main/scripts/install.sh | bash
    if command -v bd &> /dev/null; then
        echo "[OK] beads installed successfully"
    else
        echo "[WARN] beads installation may have failed. You can install manually:"
        echo "       curl -fsSL https://raw.githubusercontent.com/gastownhall/beads/main/scripts/install.sh | bash"
    fi
fi

# 2. Check for pandoc (needed for docx export)
if command -v pandoc &> /dev/null; then
    echo "[OK] pandoc is available for document export"
else
    echo "[INFO] pandoc not found — needed to export disclosures to .docx"
    echo "       Install with: brew install pandoc"
fi

echo ""
echo "=== Setup Complete ==="
echo "Use /patent-disclosure in any project to get started."
