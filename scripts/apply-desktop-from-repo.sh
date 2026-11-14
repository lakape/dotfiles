#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=== Applying Desktop & KOS settings from repository to ~/.config ==="
mkdir -p "$HOME/.config/kos"

for f in kwinrc kglobalshortcutsrc kdeglobals; do
    if [ -f "${REPO_DIR}/dotfiles/kde/$f" ]; then
        cp "${REPO_DIR}/dotfiles/kde/$f" "$HOME/.config/$f"
        chmod 600 "$HOME/.config/$f"
        echo "✓ Restored ~/.config/$f"
    fi
done

if [ -d "${REPO_DIR}/dotfiles/kos" ]; then
    cp "${REPO_DIR}/dotfiles/kos"/*.json "$HOME/.config/kos/" 2>/dev/null || true
    echo "✓ Restored ~/.config/kos/*.json"
fi

echo "Done! Restart kwin_wayland or log out/in to apply full changes."
