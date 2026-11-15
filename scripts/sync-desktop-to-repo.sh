#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=== Syncing current active Desktop & KOS settings into repository ==="
mkdir -p "${REPO_DIR}/dotfiles/kde" \
         "${REPO_DIR}/dotfiles/kos" \
         "${REPO_DIR}/dotfiles/applications" \
         "${REPO_DIR}/dotfiles/quickshell-kos" \
         "${REPO_DIR}/dotfiles/kos-share/gallery" \
         "${REPO_DIR}/dotfiles/wallpapers"

# 1. KDE configs
for f in kwinrc kglobalshortcutsrc kdeglobals kactivitymanagerdrc plasmashellrc; do
    if [ -f "$HOME/.config/$f" ]; then
        cp "$HOME/.config/$f" "${REPO_DIR}/dotfiles/kde/"
        echo "✓ Copied ~/.config/$f"
    fi
done

# 2. Desktop appletsrc (wallpaper & panel layout)
if [ -f "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" ]; then
    cp "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" "${REPO_DIR}/dotfiles/kde/"
    echo "✓ Copied ~/.config/plasma-org.kde.plasma.desktop-appletsrc"
fi

# 3. KOS JSON configs
if [ -d "$HOME/.config/kos" ]; then
    cp "$HOME/.config/kos"/*.json "${REPO_DIR}/dotfiles/kos/" 2>/dev/null || true
    echo "✓ Copied ~/.config/kos/*.json"
fi

# 4. Hidden applications overrides
if [ -d "$HOME/.local/share/applications" ]; then
    cp -r "$HOME/.local/share/applications"/* "${REPO_DIR}/dotfiles/applications/" 2>/dev/null || true
    # Don't bundle uninstalled third-party app shortcuts into fresh system dotfiles
    rm -f "${REPO_DIR}/dotfiles/applications/antigravity.desktop"
    echo "✓ Copied ~/.local/share/applications/* (excluding custom app binaries)"
fi

# 5. KOS shell & dock state (Quickshell state)
if [ -d "$HOME/.local/state/quickshell/kos" ]; then
    cp -r "$HOME/.local/state/quickshell/kos"/* "${REPO_DIR}/dotfiles/quickshell-kos/" 2>/dev/null || true
    echo "✓ Copied ~/.local/state/quickshell/kos/*"
fi

# 5. Wallpapers & gallery
if [ -f "$HOME/.local/share/kos/gallery/wallpaper.jpg" ]; then
    cp "$HOME/.local/share/kos/gallery/wallpaper.jpg" "${REPO_DIR}/dotfiles/kos-share/gallery/"
    echo "✓ Copied ~/.local/share/kos/gallery/wallpaper.jpg"
fi

if [ -d "$HOME/.local/share/wallpapers" ]; then
    cp -r "$HOME/.local/share/wallpapers"/* "${REPO_DIR}/dotfiles/wallpapers/" 2>/dev/null || true
    echo "✓ Copied ~/.local/share/wallpapers/*"
fi

echo "Done! You can now review changes with 'git diff' and commit them."
