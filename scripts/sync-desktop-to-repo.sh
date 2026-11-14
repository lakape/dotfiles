#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=== Syncing current active Desktop & KOS settings into repository ==="
mkdir -p "${REPO_DIR}/dotfiles/kde" "${REPO_DIR}/dotfiles/kos"

for f in kwinrc kglobalshortcutsrc kdeglobals; do
    if [ -f "$HOME/.config/$f" ]; then
        cp "$HOME/.config/$f" "${REPO_DIR}/dotfiles/kde/"
        echo "✓ Copied ~/.config/$f"
    fi
done

if [ -d "$HOME/.config/kos" ]; then
    cp "$HOME/.config/kos"/*.json "${REPO_DIR}/dotfiles/kos/" 2>/dev/null || true
    echo "✓ Copied ~/.config/kos/*.json"
fi

echo "Done! You can now review changes with 'git diff' and commit them."
