# Unified NixOS & KOS Desktop Configuration

Flake-based declarative NixOS configuration providing a fully integrated desktop environment based on KDE Plasma 6 and NextKDE (KOS desktop shell).

The setup is consolidated into a single configuration file (`configuration.nix`) and designed to run identically on any x86_64 UEFI machine or virtual machine.

---

## Hardware & Driver Architecture

- **Graphics:** Mesa with kernel modesetting (Intel, AMD, virtual machines). The proprietary NVIDIA driver (`nvidia.nix`) is only enabled on machines where the installer detects an NVIDIA GPU; on hybrid laptops it also sets up PRIME offload.
- **Hibernation:** A swap partition sized from the RAM (RAM + √RAM, rounded up) is created by the installer and used to resume from hibernation. zram stays the primary swap for normal operation.
- **Architecture:** x86_64 UEFI.
- **Storage footprint:** ~13–14 GiB initial disk footprint post-installation. A minimum disk partition of 50 GiB is recommended for ongoing generations, build caches, and user data.
- **Integrated tooling:** Helium browser (built-in uBlock Origin), Ladybird browser, Teams for Linux, Blip file transfer, PipeWire audio, Podman container engine, Node.js, Python 3, PostgreSQL, Apple SF-Pro typography.

---

## Automated Installation

Boot the target machine from a standard NixOS Minimal or Graphical live USB installer, verify network connectivity, and execute:

```bash
curl -sL https://raw.githubusercontent.com/lakape/dotfiles/master/scripts/install.sh | bash
```

Alternatively, pass the target disk directly as an argument:

```bash
curl -sL https://raw.githubusercontent.com/lakape/dotfiles/master/scripts/install.sh | bash -s -- /dev/nvme0n1
```

### Installation Procedure

1. Identifies the target block device (NVMe, SATA, or VirtIO) and prompts for confirmation.
2. Computes the swap size from the RAM (RAM + √RAM, rounded up; adjustable at the prompt or via `SWAP_SIZE_GIB`) and creates a GPT partition table: 512 MiB EFI system partition, Btrfs root, and a swap partition at the end of the disk.
3. Formats filesystems (`vfat` on `/boot`, `btrfs` on `/`, `swap`) and activates the swap partition.
4. Creates Btrfs subvolumes (`home`, `nix`) and mounts `/`, `/home`, and `/nix` with transparent ZSTD compression.
5. Runs `nixos-generate-config --root /mnt` to capture local hardware parameters, including the swap partition.
6. Clones this repository into `/mnt/etc/dotfiles`, copies the generated `hardware-configuration.nix` and, if an NVIDIA GPU is present, adds the `dotfiles.nvidia` settings to it.
7. Builds and installs the system via `nixos-install --no-root-passwd --flake /mnt/etc/dotfiles#nixos`.
8. Prompts for the passwords of `root` and the primary user `bigl` via `nixos-enter` (there is no default password; unattended runs must set `USER_PASSWORD`).

Once complete, reboot into the installed system:

```bash
reboot
```

---

## Manual Installation

If you prefer to partition manually or cannot use the automated script, follow these steps from the NixOS live environment:

### 1. Partition the Disk

Replace `/dev/nvme0n1` with your actual disk name:

```bash
parted -s /dev/nvme0n1 mklabel gpt
parted -s /dev/nvme0n1 mkpart ESP fat32 1MiB 512MiB
parted -s /dev/nvme0n1 set 1 esp on
parted -s /dev/nvme0n1 mkpart primary 512MiB 100%
```

### 2. Format and Mount Filesystems (Btrfs with Subvolumes)

For NVMe drives (`p1` and `p2`):

```bash
mkfs.fat -F 32 -n boot /dev/nvme0n1p1
mkfs.btrfs -f -L nixos /dev/nvme0n1p2

# Mount root and create subvolumes
mount -t btrfs -o compress=zstd /dev/nvme0n1p2 /mnt
btrfs subvolume create /mnt/home
btrfs subvolume create /mnt/nix
mkdir -p /mnt/boot

# Mount subvolumes and EFI boot partition
mount -t btrfs -o subvol=home,compress=zstd /dev/nvme0n1p2 /mnt/home
mount -t btrfs -o subvol=nix,compress=zstd,noatime /dev/nvme0n1p2 /mnt/nix
mount /dev/nvme0n1p1 /mnt/boot
```

For SATA/VirtIO drives (`/dev/sda1`/`/dev/sda2` or `/dev/vda1`/`/dev/vda2`), adjust the device paths accordingly.

### 3. Generate Hardware Configuration

```bash
nixos-generate-config --root /mnt
```

### 4. Clone Repository

```bash
git clone https://github.com/lakape/dotfiles.git /mnt/etc/dotfiles
cp /mnt/etc/nixos/hardware-configuration.nix /mnt/etc/dotfiles/hardware-configuration.nix
```

### 5. Install System

```bash
nixos-install --no-root-passwd --flake /mnt/etc/dotfiles#nixos
```

### 6. Set Root and User Passwords

```bash
# Set password for root:
nixos-enter --root /mnt -c 'passwd root'

# Set password for user 'bigl':
nixos-enter --root /mnt -c 'passwd bigl'
```

*(Note: there is no default password. Without this step neither `root` nor `bigl` can log in.)*

### 7. Reboot

```bash
reboot
```

---

## Post-Installation & Daily Workflow

### Applying System Updates

After modifying `/home/bigl/dotfiles/configuration.nix` or updating flake inputs:

```bash
rebuild
# Alias for: sudo nixos-rebuild switch --flake /home/bigl/dotfiles#nixos
```

To update flake inputs (e.g. nixpkgs, nextkde):

```bash
update-flake
# Alias for: cd /home/bigl/dotfiles && nix flake update
```

### Desktop Settings Synchronization

- **KDE Plasma** settings (shortcuts, KWin, default browser) are declared in `plasma.nix` and applied on every rebuild. To turn settings changed in the GUI into Nix code, run `nix run github:nix-community/plasma-manager#rc2nix` and copy the relevant parts into `plasma.nix`.
- **KOS** state (dock pins, tray order, launcher, appearance, window settings) lives in `dotfiles/quickshell-kos` and `dotfiles/kos`. These files are first-install defaults: a rebuild adds missing files but keeps changes made in the GUI. To make the current state the new default:
  ```bash
  ~/dotfiles/scripts/sync-desktop-to-repo.sh
  cd ~/dotfiles && git commit -am "chore: update desktop preferences" && git push
  ```
- **Plasma layout:** `dotfiles/kde/plasma-org.kde.plasma.desktop-appletsrc` is installed before the first login, so Plasma never creates its default bottom panel.

### Storage Maintenance

NixOS retains previous generations for rollbacks. To prevent unbounded disk growth, automatic weekly garbage collection and hard-link deduplication are enabled in `configuration.nix`:

- Weekly garbage collection: deletes generations older than 14 days (`nix.gc.options = "--delete-older-than 14d"`).
- Weekly store deduplication: hardlinks duplicate store files (`nix.optimise.automatic = true`).

To trigger an immediate manual cleanup:

```bash
sudo nix-collect-garbage -d
sudo nix-store --optimise
```

---

## Repository Structure

```
~/dotfiles/
├── flake.nix                  # Flake entrypoint (targets: 'nixos' and 'default')
├── flake.lock                 # Pinned dependencies
├── configuration.nix          # Consolidated system specification
├── nvidia.nix                 # NVIDIA driver, enabled per machine by the installer
├── home.nix                   # Home Manager: user files, KOS defaults, shell aliases
├── plasma.nix                 # KDE Plasma settings (plasma-manager)
├── hardware-configuration.nix # Target machine hardware scan
├── dotfiles/                  # Declaratively linked configuration assets
│   ├── kde/                   # Initial Plasma desktop layout (no panels)
│   ├── kos/                   # Window appearance and button schemas
│   ├── quickshell-kos/        # Initial quickshell state (dock, pinned apps)
│   └── wallpapers/            # Desktop backgrounds
├── fonts/                     # Apple SF-Pro font collection
├── nextkde/                   # NextKDE / KOS desktop shell source tree
└── scripts/
    ├── install.sh             # Automated installation script
    └── sync-desktop-to-repo.sh    # Copies live KOS settings back into the repo
```
