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

if [ -d "${REPO_DIR}/dotfiles/quickshell-kos" ]; then
    mkdir -p "$HOME/.local/state/quickshell/kos"
    cp -r "${REPO_DIR}/dotfiles/quickshell-kos"/* "$HOME/.local/state/quickshell/kos/" 2>/dev/null || true
    echo "✓ Restored ~/.local/state/quickshell/kos/*"
fi

if [ -d "${REPO_DIR}/dotfiles/applications" ]; then
    mkdir -p "$HOME/.local/share/applications"
    if [ ! -f "$HOME/.local/opt/antigravity/Antigravity-x64/antigravity" ]; then
        rm -f "$HOME/.local/share/applications/antigravity.desktop"
    fi
    cp "${REPO_DIR}/dotfiles/applications"/* "$HOME/.local/share/applications/" 2>/dev/null || true
    echo "✓ Synced ~/.local/share/applications/*"
fi

echo "Done! Restart kwin_wayland or log out/in to apply full changes."
