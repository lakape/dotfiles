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

# BEGIN gpu-detection
# Converts a sysfs PCI address (hex, e.g. 0000:01:00.0) into the decimal
# PCI:bus:device:function notation used by hardware.nvidia.prime.
pci_bus_id() {
    local addr="${1#*:}"
    local bus="${addr%%:*}"
    local rest="${addr#*:}"
    printf 'PCI:%d:%d:%d' "$((16#$bus))" "$((16#${rest%%.*}))" "$((16#${rest#*.}))"
}

# Prints the `dotfiles.nvidia` settings (see nvidia.nix) when an NVIDIA GPU is
# present, including PRIME bus IDs of an integrated Intel/AMD GPU. Prints nothing
# otherwise.
nvidia_settings() {
    local dev nvidia="" intel="" amd=""
    for dev in "${PCI_DEVICES_DIR:-/sys/bus/pci/devices}"/*; do
        [ -r "$dev/class" ] && [ -r "$dev/vendor" ] || continue
        case "$(cat "$dev/class")" in
            0x0300*|0x0302*|0x0380*) ;;
            *) continue ;;
        esac
        case "$(cat "$dev/vendor")" in
            0x10de) [ -n "$nvidia" ] || nvidia="$(pci_bus_id "$(basename "$dev")")" ;;
            0x8086) [ -n "$intel" ] || intel="$(pci_bus_id "$(basename "$dev")")" ;;
            0x1002) [ -n "$amd" ] || amd="$(pci_bus_id "$(basename "$dev")")" ;;
        esac
    done
    [ -n "$nvidia" ] || return 0
    printf '\n  # Added by scripts/install.sh: NVIDIA GPU detected (see nvidia.nix)\n'
    printf '  dotfiles.nvidia.enable = true;\n'
    printf '  dotfiles.nvidia.prime.nvidiaBusId = "%s";\n' "$nvidia"
    if [ -n "$intel" ]; then
        printf '  dotfiles.nvidia.prime.intelBusId = "%s";\n' "$intel"
    fi
    if [ -n "$amd" ]; then
        printf '  dotfiles.nvidia.prime.amdgpuBusId = "%s";\n' "$amd"
    fi
}

# Inserts the NVIDIA settings before the closing brace of hardware-configuration.nix.
add_nvidia_settings() {
    local hw="$1" settings
    settings="$(nvidia_settings)"
    if [ -z "$settings" ]; then
        echo "No NVIDIA GPU detected: using the open-source Mesa drivers."
        return 0
    fi
    if [ "$(tail -n 1 "$hw")" != "}" ]; then
        echo "Error: Unexpected end of $hw, cannot add the NVIDIA settings."
        return 1
    fi
    echo "NVIDIA GPU detected: enabling the proprietary driver for this machine."
    { head -n -1 "$hw"; printf '%s\n}\n' "$settings"; } > "$hw.tmp"
    mv "$hw.tmp" "$hw"
}
# END gpu-detection

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

# Swap partition for hibernation: RAM + sqrt(RAM), rounded up to whole GiB.
# Override non-interactively with SWAP_SIZE_GIB=<n>.
RAM_GIB=$(awk '/^MemTotal:/ { printf "%d", ($2 + 1048575) / 1048576 }' /proc/meminfo)
SWAP_GIB=$(awk -v r="$RAM_GIB" 'BEGIN { s = sqrt(r); printf "%d", r + ((s == int(s)) ? s : int(s) + 1) }')
if [ -n "${SWAP_SIZE_GIB:-}" ]; then
    SWAP_GIB="$SWAP_SIZE_GIB"
elif [ -e /dev/tty ]; then
    read -r -p "Swap partition size in GiB (RAM: ${RAM_GIB} GiB) [Default: ${SWAP_GIB}]: " SWAP_INPUT < /dev/tty || SWAP_INPUT=""
    SWAP_GIB="${SWAP_INPUT:-$SWAP_GIB}"
fi
if ! [[ "$SWAP_GIB" =~ ^[0-9]+$ ]] || [ "$SWAP_GIB" -lt 1 ]; then
    echo "Error: Invalid swap size '$SWAP_GIB'."
    exit 1
fi
if [ "$SWAP_GIB" -lt "$RAM_GIB" ]; then
    echo "Warning: ${SWAP_GIB} GiB swap is smaller than the RAM (${RAM_GIB} GiB); hibernation may fail."
fi

DISK_GIB=$(( $(blockdev --getsize64 "$TARGET_DISK") / 1073741824 ))
MIN_ROOT_GIB=30
if [ $(( DISK_GIB - SWAP_GIB - 1 )) -lt "$MIN_ROOT_GIB" ]; then
    echo "Error: ${DISK_GIB} GiB disk is too small for ${SWAP_GIB} GiB swap plus a ${MIN_ROOT_GIB} GiB root partition."
    exit 1
fi
echo "Partition layout: 512 MiB EFI | ~$(( DISK_GIB - SWAP_GIB - 1 )) GiB Btrfs root | ${SWAP_GIB} GiB swap"

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
swapoff "${TARGET_DISK}"* 2>/dev/null || true

echo "[2/6] Partitioning '$TARGET_DISK' (GPT: 512MiB EFI, Btrfs root, ${SWAP_GIB}GiB swap)..."
parted -s "$TARGET_DISK" mklabel gpt
parted -s "$TARGET_DISK" mkpart ESP fat32 1MiB 512MiB
parted -s "$TARGET_DISK" set 1 esp on
# "--" stops option parsing, so the negative end positions (counted from the end of the disk) work
parted -s "$TARGET_DISK" -- mkpart primary 512MiB "-${SWAP_GIB}GiB"
parted -s "$TARGET_DISK" -- mkpart swap linux-swap "-${SWAP_GIB}GiB" 100%

# Determine partition paths (NVMe: /dev/nvme0n1p1 vs SATA: /dev/sda1 vs VirtIO: /dev/vda1)
if [[ "$TARGET_DISK" =~ [0-9]$ ]]; then
    BOOT_PART="${TARGET_DISK}p1"
    ROOT_PART="${TARGET_DISK}p2"
    SWAP_PART="${TARGET_DISK}p3"
else
    BOOT_PART="${TARGET_DISK}1"
    ROOT_PART="${TARGET_DISK}2"
    SWAP_PART="${TARGET_DISK}3"
fi

# Wait until udev has created the new partition device nodes
udevadm settle 2>/dev/null || sleep 2

echo "[3/6] Formatting filesystems (FAT32 on boot, Btrfs on root, swap)..."
mkfs.fat -F 32 -n boot "$BOOT_PART"
mkfs.btrfs -f -L nixos "$ROOT_PART"
mkswap -L swap "$SWAP_PART"

echo "[4/6] Creating Btrfs subvolumes and mounting to /mnt..."
mount -t btrfs -o compress=zstd "$ROOT_PART" /mnt
btrfs subvolume create /mnt/home
btrfs subvolume create /mnt/nix
mkdir -p /mnt/boot

mount -t btrfs -o subvol=home,compress=zstd "$ROOT_PART" /mnt/home
mount -t btrfs -o subvol=nix,compress=zstd,noatime "$ROOT_PART" /mnt/nix
mount "$BOOT_PART" /mnt/boot

# Active swap is recorded in hardware-configuration.nix (used for hibernation)
# and also keeps the build from running out of memory.
swapon "$SWAP_PART"

# Temporary zram swap only if the swap partition is unusually small
if [ "$(free -m | awk '/Swap:/ {print $2}')" -lt 4000 ]; then
    echo "Adding temporary 12G zram swap to prevent Out-Of-Memory during the build..."
    modprobe zram 2>/dev/null || true
    if ZRAM_DEV=$(zramctl --find --size 12G 2>/dev/null); then
        mkswap "$ZRAM_DEV" >/dev/null && swapon -p 100 "$ZRAM_DEV" || true
    fi
fi

echo "[5/6] Generating hardware configuration for target machine..."
nixos-generate-config --root /mnt

echo "[6/6] Cloning configuration repository..."
DOTFILES_DIR="/mnt/etc/dotfiles"
if [ ! -d "$DOTFILES_DIR" ]; then
    if [ -d "/home/nixos/dotfiles" ]; then
        echo "Copying dotfiles from local system..."
        cp -r /home/nixos/dotfiles "$DOTFILES_DIR"
    else
        git clone https://github.com/lakape/dotfiles.git "$DOTFILES_DIR"
    fi
fi
cp /mnt/etc/nixos/hardware-configuration.nix "$DOTFILES_DIR/hardware-configuration.nix"
add_nvidia_settings "$DOTFILES_DIR/hardware-configuration.nix"
git -C "$DOTFILES_DIR" add "$DOTFILES_DIR/hardware-configuration.nix" 2>/dev/null || true

FLAKE_TARGET="nixos"
git -C "$DOTFILES_DIR" config --global --add safe.directory "*" 2>/dev/null || true

echo "=========================================================="
echo "    Running nixos-install (--flake .#$FLAKE_TARGET)...   "
echo "=========================================================="
nixos-install --no-root-passwd --flake "$DOTFILES_DIR#$FLAKE_TARGET" --max-jobs auto --cores 4

echo ""
echo "=========================================================="
echo "    Setting passwords for users 'root' and 'bigl'...      "
echo "=========================================================="
DEFAULT_PASSWORD="${USER_PASSWORD:-975159}"
if [ -t 0 ] && [ -e /dev/tty ] && [ "${CI:-}" != "1" ] && [ -z "${AUTOMATED:-}" ]; then
    echo "Setting root password:"
    nixos-enter --root /mnt -c 'passwd root' < /dev/tty || echo "root:$DEFAULT_PASSWORD" | nixos-enter --root /mnt -c 'chpasswd'
    echo "Setting bigl password:"
    nixos-enter --root /mnt -c 'passwd bigl' < /dev/tty || echo "bigl:$DEFAULT_PASSWORD" | nixos-enter --root /mnt -c 'chpasswd'
else
    echo "Setting root and bigl passwords non-interactively..."
    echo "root:$DEFAULT_PASSWORD" | nixos-enter --root /mnt -c 'chpasswd'
    echo "bigl:$DEFAULT_PASSWORD" | nixos-enter --root /mnt -c 'chpasswd'
fi

echo ""
echo "=========================================================="
echo "    Provisioning user repository in /home/bigl/dotfiles... "
echo "=========================================================="
mkdir -p /mnt/home/bigl
cp -r "$DOTFILES_DIR" "/mnt/home/bigl/dotfiles"
nixos-enter --root /mnt -c 'chown -R bigl:users /home/bigl/dotfiles' 2>/dev/null || true

echo "=========================================================="
echo "    Installation completed successfully.                  "
echo "    You can now reboot into your new system with: reboot  "
echo "=========================================================="
