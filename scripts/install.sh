#!/usr/bin/env bash
set -euo pipefail

# Elevate to root. When the script is piped into bash ("curl ... | bash") there
# is no script file that sudo could run again, so explain the working variant.
if [ "$EUID" -ne 0 ]; then
    if [ -f "$0" ]; then
        exec sudo bash "$0" "$@"
    fi
    echo "Error: This script must run as root. Use:"
    echo "  curl -fsSL https://raw.githubusercontent.com/lakape/dotfiles/master/scripts/install.sh | sudo bash -s -- /dev/<disk>"
    exit 1
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

# Prompts go to the terminal. Unattended runs (no terminal, CI=1 or AUTOMATED set)
# skip all prompts and must provide USER_PASSWORD (used for root and bigl);
# there is no built-in default password.
if { : < /dev/tty; } 2>/dev/null && [ "${CI:-}" != "1" ] && [ -z "${AUTOMATED:-}" ]; then
    INTERACTIVE=1
else
    INTERACTIVE=0
    if [ -z "${USER_PASSWORD:-}" ]; then
        echo "Error: Unattended installation requires USER_PASSWORD to be set."
        exit 1
    fi
fi

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

    if [ "$INTERACTIVE" = 1 ]; then
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
elif [ "$INTERACTIVE" = 1 ]; then
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
echo "Partition layout: 1 GiB EFI | ~$(( DISK_GIB - SWAP_GIB - 1 )) GiB Btrfs root | ${SWAP_GIB} GiB swap"

if [ "$INTERACTIVE" = 1 ]; then
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

echo "[2/6] Partitioning '$TARGET_DISK' (GPT: 1GiB EFI, Btrfs root, ${SWAP_GIB}GiB swap)..."
parted -s "$TARGET_DISK" mklabel gpt
# 1 GiB EFI partition: room for several generations of the latest kernel and initrd
parted -s "$TARGET_DISK" mkpart ESP fat32 1MiB 1025MiB
parted -s "$TARGET_DISK" set 1 esp on
# "--" stops option parsing, so the negative end positions (counted from the end of the disk) work
parted -s "$TARGET_DISK" -- mkpart primary 1025MiB "-${SWAP_GIB}GiB"
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
# The repository lives in the user's home; the system is installed and later
# rebuilt from there (see the "rebuild" alias in home.nix).
DOTFILES_DIR="/mnt/home/bigl/dotfiles"
mkdir -p /mnt/home/bigl
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
# The hardware configuration is machine-specific: keep it out of git status and
# commits. Nix still reads the local file when building the flake.
git -C "$DOTFILES_DIR" update-index --skip-worktree hardware-configuration.nix

# This system is built from the flake only. Remove the generated default
# configuration, so a plain `nixos-rebuild` fails instead of building it.
rm -f /mnt/etc/nixos/configuration.nix

FLAKE_TARGET="nixos"
git -C "$DOTFILES_DIR" config --global --add safe.directory "*" 2>/dev/null || true

echo "=========================================================="
echo "    Running nixos-install (--flake .#$FLAKE_TARGET)...   "
echo "=========================================================="
# At most 4 cores per build: compiling with all cores ran out of memory and
# crashed the live installer on a laptop with 8 GiB RAM.
nixos-install --no-root-passwd --flake "$DOTFILES_DIR#$FLAKE_TARGET" --max-jobs auto --cores 4

echo ""
echo "=========================================================="
echo "    Setting passwords for users 'root' and 'bigl'...      "
echo "=========================================================="
set_password() {
    local user="$1"
    if [ "$INTERACTIVE" = 1 ]; then
        echo "Setting password for '$user':"
        until nixos-enter --root /mnt -c "passwd $user" < /dev/tty; do
            echo "The password was not set, please try again."
        done
    else
        printf '%s:%s\n' "$user" "$USER_PASSWORD" | nixos-enter --root /mnt -c 'chpasswd'
    fi
}
set_password root
set_password bigl

# The home directory and the repository were created by root before bigl existed
nixos-enter --root /mnt -c 'chown bigl:users /home/bigl && chmod 700 /home/bigl && chown -R bigl:users /home/bigl/dotfiles'

echo "=========================================================="
echo "    Installation completed successfully.                  "
echo "    You can now reboot into your new system with: reboot  "
echo "=========================================================="
