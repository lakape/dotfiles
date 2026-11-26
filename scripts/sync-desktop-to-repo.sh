#!/usr/bin/env bash
# Copies the live KOS desktop state back into the repository, so changes made
# in the GUI (dock pins, tray order, launcher, appearance, window settings)
# become the defaults for new installations (see home.nix: seedKosConfigs).
#
# Only files that already exist in the repository are updated, so runtime
# caches never end up in git. KDE Plasma settings are declared in plasma.nix;
# to turn current KDE settings into Nix code run:
#   nix run github:nix-community/plasma-manager#rc2nix
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Text files store the home directory as @HOME@ (home.nix fills it in), so the
# repository does not depend on the user name.
to_repo_form() {
    if grep -qI -F -- "$HOME" "$1"; then
        sed "s|$HOME|@HOME@|g" "$1"
    else
        cat "$1"
    fi
}

# Usage: sync_tracked <live dir> <repository dir>
sync_tracked() {
    local live="$1" repo="$2" file rel
    while IFS= read -r -d '' file; do
        rel="${file#"$repo"/}"
        if [ -f "$live/$rel" ] && ! to_repo_form "$live/$rel" | cmp -s - "$file"; then
            to_repo_form "$live/$rel" > "$file"
            echo "✓ Updated ${file#"$REPO_DIR"/}"
        fi
    done < <(find "$repo" -type f -print0)
}

echo "=== Syncing live KOS desktop state into the repository ==="
sync_tracked "$HOME/.local/state/quickshell/kos" "$REPO_DIR/dotfiles/quickshell-kos"
sync_tracked "$HOME/.config/kos" "$REPO_DIR/dotfiles/kos"
sync_tracked "$HOME/.local/share/kos/gallery" "$REPO_DIR/dotfiles/kos-share/gallery"

echo "Done. Review the changes with: git -C \"$REPO_DIR\" diff"
