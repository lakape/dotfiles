#!/usr/bin/env bash
set -euo pipefail

# Automatisch zu root wechseln, falls als normaler Benutzer gestartet
if [ "$EUID" -ne 0 ]; then
  exec sudo bash "$0" "$@"
fi

echo "=========================================================="
echo "    Universeller NixOS & KOS Installer für JEDEN PC      "
echo "=========================================================="

# 1. Festplatte ermitteln
TARGET_DISK="${1:-}"

if [ -z "$TARGET_DISK" ]; then
    echo ""
    echo "Gefundene Festplatten auf diesem System:"
    lsblk -d -n -o NAME,SIZE,MODEL,TYPE | awk '$4=="disk"{print "  /dev/" $1 " (" $2 ", " $3 ")"}'
    echo ""
    
    # Automatischen Vorschlag wählen (erste gefundene Platte)
    DEFAULT_DISK=$(lsblk -d -n -o NAME,TYPE | awk '$2=="disk"{print "/dev/"$1; exit}')
    
    if [ -t 0 ]; then
        read -r -p "Auf welche Festplatte soll installiert werden? [Standard: ${DEFAULT_DISK}]: " USER_INPUT
        TARGET_DISK="${USER_INPUT:-$DEFAULT_DISK}"
    else
        TARGET_DISK="$DEFAULT_DISK"
    fi
fi

if [ ! -b "$TARGET_DISK" ]; then
    echo "Fehler: Festplatte '$TARGET_DISK' wurde nicht gefunden!"
    exit 1
fi

echo "Ausgewählte Zielfestplatte: $TARGET_DISK"

if [ -t 0 ]; then
    echo ""
    echo "ACHTUNG: Alle bestehenden Daten auf '$TARGET_DISK' werden gelöscht!"
    read -r -p "Möchtest du wirklich fortfahren? (ja/nein): " CONFIRM
    if [[ "$CONFIRM" != "ja" && "$CONFIRM" != "y" && "$CONFIRM" != "yes" ]]; then
        echo "Installation abgebrochen."
        exit 0
    fi
fi

echo ""
echo "[1/6] Löse eventuell bestehende Mounts..."
umount -R /mnt 2>/dev/null || true
swapoff -a 2>/dev/null || true

echo "[2/6] Partitioniere '$TARGET_DISK' (GPT: 512MiB EFI, Rest Root)..."
parted -s "$TARGET_DISK" mklabel gpt
parted -s "$TARGET_DISK" mkpart ESP fat32 1MiB 512MiB
parted -s "$TARGET_DISK" set 1 esp on
parted -s "$TARGET_DISK" mkpart primary ext4 512MiB 100%

# Partitionspfade ermitteln (NVMe: /dev/nvme0n1p1 vs SATA: /dev/sda1 vs VirtIO: /dev/vda1)
if [[ "$TARGET_DISK" =~ [0-9]$ ]]; then
    BOOT_PART="${TARGET_DISK}p1"
    ROOT_PART="${TARGET_DISK}p2"
else
    BOOT_PART="${TARGET_DISK}1"
    ROOT_PART="${TARGET_DISK}2"
fi

# Kernel Zeit geben, die neue Partitionstabelle einzulesen
sleep 2

echo "[3/6] Formatiere Dateisysteme ($BOOT_PART und $ROOT_PART)..."
mkfs.fat -F 32 -n boot "$BOOT_PART"
mkfs.ext4 -F -L nixos "$ROOT_PART"

echo "[4/6] Mounte Partitionen nach /mnt..."
mount "$ROOT_PART" /mnt
mkdir -p /mnt/boot
mount "$BOOT_PART" /mnt/boot

echo "[5/6] Erfasse Hardware-Konfiguration dieses PCs..."
nixos-generate-config --root /mnt

echo "[6/6] Klone dotfiles-Repository..."
DOTFILES_DIR="/mnt/etc/dotfiles"
if [ ! -d "$DOTFILES_DIR" ]; then
    git clone https://github.com/lakape/dotfiles.git "$DOTFILES_DIR"
fi
cp /mnt/etc/nixos/hardware-configuration.nix "$DOTFILES_DIR/hardware-configuration.nix"

# Hardware-Erkennung für dedizierte GPU
FLAKE_TARGET="nixos"
if lspci 2>/dev/null | grep -iE "vga|3d|display" | grep -iq "nvidia"; then
    echo "-> NVIDIA GPU erkannt! Wähle Flake-Profil: workstation (mit NVIDIA & PRIME)"
    FLAKE_TARGET="workstation"
else
    echo "-> Standard-Grafik (Intel/AMD/Mesa/VM) erkannt! Wähle Flake-Profil: nixos"
    FLAKE_TARGET="nixos"
fi

echo "=========================================================="
echo "    Starte nixos-install (--flake .#$FLAKE_TARGET)...     "
echo "=========================================================="
nixos-install --flake "$DOTFILES_DIR#$FLAKE_TARGET"

echo "=========================================================="
echo "    INSTALLATION ERFOLGREICH ABGESCHLOSSEN!               "
echo "    Du kannst den Rechner jetzt mit 'reboot' neustarten.  "
echo "=========================================================="
