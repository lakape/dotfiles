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
    mapfile -t DISKS < <(lsblk -d -n -o NAME,TYPE | awk '$2=="disk" && $1 !~ /^(fd|loop|sr|ram|zram)/ {print $1}')

    if [ ${#DISKS[@]} -eq 0 ]; then
        echo "Error: No suitable install disk found on this system."
        exit 1
    fi

    echo ""
    echo "Detected block devices on this system:"
    for d in "${DISKS[@]}"; do
        size=$(lsblk -d -n -o SIZE "/dev/$d" 2>/dev/null || echo "")
        model=$(lsblk -d -n -o MODEL "/dev/$d" 2>/dev/null || echo "")
        echo "  /dev/$d (${size}${model:+, $model})"
    done
    echo ""

    # Choose smart default: prefer nvme, then vd, then first disk
    DEFAULT_DISK="/dev/${DISKS[0]}"
    for d in "${DISKS[@]}"; do
        if [[ "$d" =~ ^nvme ]]; then
            DEFAULT_DISK="/dev/$d"
            break
        elif [[ "$d" =~ ^vd ]]; then
            DEFAULT_DISK="/dev/$d"
        fi
    done

    if [ -e /dev/tty ]; then
        read -r -p "Target disk [Default: ${DEFAULT_DISK}]: " USER_INPUT < /dev/tty || USER_INPUT=""
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

if [ -e /dev/tty ]; then
    echo ""
    echo "WARNING: All existing data on '$TARGET_DISK' will be permanently erased!"
    read -r -p "Are you sure you want to proceed? (y/N): " CONFIRM < /dev/tty || CONFIRM="n"
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
if [ -e /dev/tty ]; then
    nixos-enter --root /mnt -c 'passwd root' < /dev/tty
else
    nixos-enter --root /mnt -c 'passwd root'
fi

echo ""
echo "=========================================================="
echo "    Set password for user 'bigl':                         "
echo "=========================================================="
if [ -e /dev/tty ]; then
    nixos-enter --root /mnt -c 'passwd bigl' < /dev/tty
else
    nixos-enter --root /mnt -c 'passwd bigl'
fi

echo ""
echo "=========================================================="
echo "    Pre-installing latest uBlock Origin for Chromium...  "
echo "=========================================================="
EXT_DIR="/mnt/home/bigl/.local/share/ungoogled-chromium/extensions"
EXT_JSON_DIR="/mnt/home/bigl/.config/chromium/External Extensions"
mkdir -p "$EXT_DIR" "$EXT_JSON_DIR"

python3 - << 'PYEOF' || true
import urllib.request, xml.etree.ElementTree as ET, json, os, sys

try:
    url = "https://raw.githubusercontent.com/gorhill/uBlock/master/dist/chromium/update.xml"
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=15) as r:
        tree = ET.fromstring(r.read())
    for app in tree.iter("{http://www.google.com/update2/response}app"):
        if app.attrib.get("appid") == "fkgkibajhfbepljeaefdnfnegdcjomkh":
            for uc in app.iter("{http://www.google.com/update2/response}updatecheck"):
                version = uc.attrib.get("version")
                codebase = uc.attrib.get("codebase")
                print(f"Fetching uBlock Origin {version}...")
                crx_file = "/mnt/home/bigl/.local/share/ungoogled-chromium/extensions/ublock.crx"
                json_file = "/mnt/home/bigl/.config/chromium/External Extensions/fkgkibajhfbepljeaefdnfnegdcjomkh.json"
                req_dl = urllib.request.Request(codebase, headers={"User-Agent": "Mozilla/5.0"})
                with urllib.request.urlopen(req_dl, timeout=30) as resp, open(crx_file, "wb") as f:
                    f.write(resp.read())
                with open(json_file, "w") as f:
                    json.dump({"external_crx": "/home/bigl/.local/share/ungoogled-chromium/extensions/ublock.crx", "external_version": version}, f, indent=2)
                print(f"uBlock Origin {version} installed successfully.")
except Exception as e:
    print(f"Notice: Could not fetch latest release dynamically ({e}). System baseline will be used.", file=sys.stderr)
PYEOF

nixos-enter --root /mnt -c 'chown -R bigl:users /home/bigl/.local /home/bigl/.config' 2>/dev/null || true

echo "=========================================================="
echo "    Installation completed successfully.                  "
echo "    You can now reboot into your new system with: reboot  "
echo "=========================================================="
