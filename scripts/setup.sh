#!/usr/bin/env bash
# Patent Disclosure Plugin — Setup
# Installs and configures the prerequisites needed by the skill.
#
# MANDATORY: gogcli (gog)   — Google Docs is the only supported final output.
# RECOMMENDED: mermaid-cli  — renders diagrams as PNGs inside the Google Doc.
# OPTIONAL:  pandoc, beads  — docx fallback, cross-session tracking.

set -euo pipefail

echo "=== Patent Disclosure Plugin — Setup ==="
echo ""
echo "The patent-disclosure skill publishes every disclosure to Google Docs."
echo "gogcli (gog) is REQUIRED. This script walks you through the setup."
echo ""

# --- 1. Homebrew (needed to install gog) ---
if ! command -v brew &> /dev/null; then
    echo "[ERROR] Homebrew not found."
    echo "        Install it from https://brew.sh and rerun this script."
    echo "        If you cannot use Homebrew, see https://github.com/tmc/gogcli"
    echo "        for alternative install methods, then rerun."
    exit 1
fi
echo "[OK] Homebrew is installed"

# --- 2. Install gogcli if missing ---
if ! command -v gog &> /dev/null; then
    echo ""
    echo "[INSTALLING] gogcli via Homebrew..."
    brew install gogcli
fi

if ! command -v gog &> /dev/null; then
    echo "[ERROR] gogcli installation failed."
    echo "        Install manually (https://github.com/tmc/gogcli) and rerun."
    exit 1
fi
echo "[OK] gogcli installed: $(gog --version 2>/dev/null || echo 'version unknown')"

# --- 3. Walk user through Google OAuth ---
echo ""
echo "=== Google account authorization ==="

# `gog auth status` only prints config paths — it does NOT report sign-in state.
# The reliable probe is `gog auth list --json` which returns {"accounts": [...]}.
AUTHED_ACCOUNTS=$(gog auth list --json 2>/dev/null | grep -o '"email"' | wc -l | tr -d ' ')

if [ "${AUTHED_ACCOUNTS}" -gt 0 ]; then
    echo "[OK] gog has ${AUTHED_ACCOUNTS} authorized account(s):"
    gog auth list --plain 2>/dev/null | awk 'NR>1 {print "     - " $0}' || true
    echo ""
    read -p "Add another account? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "[SKIP] Using existing authorization."
    else
        AUTHED_ACCOUNTS=0
    fi
fi

if [ "${AUTHED_ACCOUNTS}" -eq 0 ]; then
    echo "gog is not yet authorized against a Google account."
    echo ""
    echo "You will sign in with the Google account you want disclosures published"
    echo "under — usually your work account. A browser window will open."
    echo ""
    read -p "Enter the Google account email to authorize: " GOG_EMAIL
    if [ -z "${GOG_EMAIL}" ]; then
        echo "[ERROR] No email entered. Rerun this script when ready."
        exit 1
    fi
    echo ""
    echo "[RUNNING] gog login ${GOG_EMAIL}"
    echo "          (complete the OAuth flow in the browser window that opens)"
    echo ""
    if ! gog login "${GOG_EMAIL}"; then
        echo "[ERROR] gog login failed. Rerun this script after resolving the issue."
        echo "        If your admin requires explicit scopes, try:"
        echo "           gog login ${GOG_EMAIL} --scopes drive,docs"
        exit 1
    fi
    # Verify by re-probing
    if ! gog auth list --json 2>/dev/null | grep -q '"email"'; then
        echo "[ERROR] No authorized account after login. Rerun the script."
        exit 1
    fi
    echo "[OK] gog authorized as ${GOG_EMAIL}"
fi

# --- 4. mermaid-cli (recommended) ---
echo ""
if command -v mmdc &> /dev/null; then
    echo "[OK] mermaid-cli (mmdc) available"
else
    echo "[INSTALLING] mermaid-cli via npm..."
    if command -v npm &> /dev/null; then
        npm install -g @mermaid-js/mermaid-cli || echo "[WARN] npm install failed — diagrams will appear as code blocks in the Google Doc."
    else
        echo "[WARN] npm not found. Install Node.js and run:"
        echo "       npm install -g @mermaid-js/mermaid-cli"
        echo "       Without mermaid-cli, diagrams appear as code blocks in the doc."
    fi
fi

# --- 5. pandoc (optional, for .docx fallback) ---
if command -v pandoc &> /dev/null; then
    echo "[OK] pandoc available (docx export fallback)"
else
    echo "[INFO] pandoc not found — only needed for .docx export."
    echo "       Install with: brew install pandoc"
fi

# --- 6. beads (optional) ---
if command -v bd &> /dev/null; then
    echo "[OK] beads (bd) available for cross-session tracking"
else
    echo "[INFO] beads not installed (optional). To install:"
    echo "       curl -fsSL https://raw.githubusercontent.com/gastownhall/beads/main/scripts/install.sh | bash"
fi

# --- 7. Output directory ---
mkdir -p patent-disclosures
echo "[OK] patent-disclosures/ directory ready"

echo ""
echo "=== Setup Complete ==="
echo "gogcli is installed and authorized. Every disclosure will be published to"
echo "Google Docs — no local-only output."
echo ""
echo "Run /patent-disclosure in any project to begin."
