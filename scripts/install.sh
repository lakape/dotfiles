#!/usr/bin/env bash
set -euo pipefail

# Elevate to root if not already
if [ "$EUID" -ne 0 ]; then
  exec sudo bash "$0" "$@"
fi

echo "=========================================================="
echo "    Universal NixOS & KOS Installation Script             "
echo "=========================================================="

TARGET_DISK="${1:-}"

if [ -z "$TARGET_DISK" ]; then
    echo ""
    echo "Detected block devices on this system:"
    lsblk -d -n -o NAME,SIZE,MODEL,TYPE | awk '$4=="disk"{print "  /dev/" $1 " (" $2 ", " $3 ")"}'
    echo ""

    DEFAULT_DISK=$(lsblk -d -n -o NAME,TYPE | awk '$2=="disk"{print "/dev/"$1; exit}')

    if [ -t 0 ]; then
        read -r -p "Target disk [Default: ${DEFAULT_DISK}]: " USER_INPUT
        TARGET_DISK="${USER_INPUT:-$DEFAULT_DISK}"
    else
        TARGET_DISK="$DEFAULT_DISK"
    fi
fi

if [ ! -b "$TARGET_DISK" ]; then
    echo "Error: Device '$TARGET_DISK' not found."
    exit 1
fi

echo "Selected target disk: $TARGET_DISK"

if [ -t 0 ]; then
    echo ""
    echo "WARNING: All existing data on '$TARGET_DISK' will be permanently erased!"
    read -r -p "Are you sure you want to proceed? (y/N): " CONFIRM
    if [[ "$CONFIRM" != "y" && "$CONFIRM" != "yes" && "$CONFIRM" != "ja" ]]; then
        echo "Installation aborted."
        exit 0
    fi
fi

echo ""
echo "[1/6] Unmounting existing partitions..."
umount -R /mnt 2>/dev/null || true
swapoff -a 2>/dev/null || true

echo "[2/6] Partitioning '$TARGET_DISK' (GPT: 512MiB EFI, rest Btrfs root)..."
parted -s "$TARGET_DISK" mklabel gpt
parted -s "$TARGET_DISK" mkpart ESP fat32 1MiB 512MiB
parted -s "$TARGET_DISK" set 1 esp on
parted -s "$TARGET_DISK" mkpart primary 512MiB 100%

# Determine partition paths (NVMe: /dev/nvme0n1p1 vs SATA: /dev/sda1 vs VirtIO: /dev/vda1)
if [[ "$TARGET_DISK" =~ [0-9]$ ]]; then
    BOOT_PART="${TARGET_DISK}p1"
    ROOT_PART="${TARGET_DISK}p2"
else
    BOOT_PART="${TARGET_DISK}1"
    ROOT_PART="${TARGET_DISK}2"
fi

sleep 2

echo "[3/6] Formatting filesystems (FAT32 on boot, Btrfs on root)..."
mkfs.fat -F 32 -n boot "$BOOT_PART"
mkfs.btrfs -f -L nixos "$ROOT_PART"

echo "[4/6] Creating Btrfs subvolumes and mounting to /mnt..."
mount -t btrfs -o compress=zstd "$ROOT_PART" /mnt
btrfs subvolume create /mnt/home
btrfs subvolume create /mnt/nix
mkdir -p /mnt/boot

mount -t btrfs -o subvol=home,compress=zstd "$ROOT_PART" /mnt/home
mount -t btrfs -o subvol=nix,compress=zstd,noatime "$ROOT_PART" /mnt/nix
mount "$BOOT_PART" /mnt/boot

echo "[5/6] Generating hardware configuration for target machine..."
nixos-generate-config --root /mnt

echo "[6/6] Cloning configuration repository..."
DOTFILES_DIR="/mnt/etc/dotfiles"
if [ ! -d "$DOTFILES_DIR" ]; then
    git clone https://github.com/lakape/dotfiles.git "$DOTFILES_DIR"
fi
cp /mnt/etc/nixos/hardware-configuration.nix "$DOTFILES_DIR/hardware-configuration.nix"

FLAKE_TARGET="nixos"

echo "=========================================================="
echo "    Running nixos-install (--flake .#$FLAKE_TARGET)...   "
echo "=========================================================="
nixos-install --no-root-passwd --flake "$DOTFILES_DIR#$FLAKE_TARGET"

echo ""
echo "=========================================================="
echo "    Set password for user 'root':                         "
echo "=========================================================="
nixos-enter --root /mnt -c 'passwd root'

echo ""
echo "=========================================================="
echo "    Set password for user 'bigl':                         "
echo "=========================================================="
nixos-enter --root /mnt -c 'passwd bigl'

echo "=========================================================="
echo "    Installation completed successfully.                  "
echo "    You can now reboot into your new system with: reboot  "
echo "=========================================================="
