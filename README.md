# Unified NixOS & KOS Desktop Configuration

Flake-based declarative NixOS configuration providing a fully integrated desktop environment based on KDE Plasma 6 and NextKDE (KOS desktop shell).

The system is described by `configuration.nix` (system), `home.nix` and `plasma.nix` (user, via Home Manager and plasma-manager) and `nvidia.nix` (optional driver). Only `hardware-configuration.nix` is machine-specific; the installer generates it. The setup runs on any x86_64 UEFI machine or virtual machine.

---

## Hardware & System Overview

- **Graphics:** Mesa with kernel modesetting (Intel, AMD, virtual machines). The proprietary NVIDIA driver (`nvidia.nix`) is only enabled on machines where the installer detects an NVIDIA GPU; on hybrid laptops it also sets up PRIME offload.
- **Storage:** Btrfs with transparent zstd compression and the subvolumes `home` and `nix`.
- **Hibernation:** The installer creates a swap partition sized from the RAM (RAM + √RAM, rounded up), which is used to resume from hibernation. zram stays the primary swap for normal operation.
- **Boot:** systemd-boot on a 1 GiB EFI partition; the five newest generations are kept in the boot menu.
- **Storage footprint:** ~13–14 GiB after installation. At least 50 GiB of disk space is recommended for generations, build caches and user data (plus the swap partition).
- **Applications:** Helium browser (built-in uBlock Origin, Bitwarden installed by policy), Ladybird browser, Teams for Linux, Blip file transfer, PipeWire audio, Podman, Node.js, Python 3, PostgreSQL client, Apple SF-Pro fonts.

---

## Automated Installation

Boot the target machine from a NixOS live USB (Minimal or Graphical), make sure the network works, then download and run the installer:

```bash
curl -fsSL https://raw.githubusercontent.com/lakape/dotfiles/master/scripts/install.sh -o /tmp/install.sh
bash /tmp/install.sh /dev/nvme0n1
```

The script asks for root rights itself. Without a disk argument it lists the detected disks and asks which one to use. It can also be piped directly into a root shell:

```bash
curl -fsSL https://raw.githubusercontent.com/lakape/dotfiles/master/scripts/install.sh | sudo bash -s -- /dev/nvme0n1
```

**Unattended installation:** set `AUTOMATED=1` (or `CI=1`) and `USER_PASSWORD=<password>` (used for `root` and `bigl`). All prompts are skipped, so the disk is erased without confirmation. `SWAP_SIZE_GIB=<n>` overrides the computed swap size.

### Installation Procedure

1. Selects the target disk (NVMe, SATA or VirtIO) and asks for the swap size (default: RAM + √RAM, rounded up) and for confirmation.
2. Creates a GPT partition table: 1 GiB EFI system partition, Btrfs root, and a swap partition at the end of the disk.
3. Formats the partitions (`vfat` on `/boot`, `btrfs` on `/`, `swap`) and creates the Btrfs subvolumes `home` and `nix`.
4. Mounts everything with zstd compression and activates the swap partition.
5. Runs `nixos-generate-config --root /mnt`, which records the hardware and the swap partition.
6. Clones this repository into `/mnt/home/bigl/dotfiles` and copies the generated `hardware-configuration.nix` into it. If an NVIDIA GPU is present, the `dotfiles.nvidia` settings are added to that file. The file is marked with `git update-index --skip-worktree`, so it never shows up as a change.
7. Installs the system with `nixos-install --flake /mnt/home/bigl/dotfiles#nixos`.
8. Asks for the passwords of `root` and `bigl` (there is no default password) and hands the home directory over to `bigl`.

Afterwards, reboot into the installed system:

```bash
reboot
```

---

## Manual Installation

If you prefer to partition by hand, run these steps in the NixOS live environment. Replace `/dev/nvme0n1` with your disk; SATA and VirtIO disks use `/dev/sda1` or `/dev/vda1` instead of `p1`.

### 1. Partition the Disk

Choose a swap size of at least your RAM (example: 11 GiB for 8 GiB RAM):

```bash
parted -s /dev/nvme0n1 mklabel gpt
parted -s /dev/nvme0n1 mkpart ESP fat32 1MiB 1025MiB
parted -s /dev/nvme0n1 set 1 esp on
parted -s /dev/nvme0n1 -- mkpart primary 1025MiB -11GiB
parted -s /dev/nvme0n1 -- mkpart swap linux-swap -11GiB 100%
```

### 2. Format and Mount

```bash
mkfs.fat -F 32 -n boot /dev/nvme0n1p1
mkfs.btrfs -f -L nixos /dev/nvme0n1p2
mkswap -L swap /dev/nvme0n1p3

mount -t btrfs -o compress=zstd /dev/nvme0n1p2 /mnt
btrfs subvolume create /mnt/home
btrfs subvolume create /mnt/nix
mkdir -p /mnt/boot
mount -t btrfs -o subvol=home,compress=zstd /dev/nvme0n1p2 /mnt/home
mount -t btrfs -o subvol=nix,compress=zstd,noatime /dev/nvme0n1p2 /mnt/nix
mount /dev/nvme0n1p1 /mnt/boot

# Active swap is recorded in hardware-configuration.nix (needed for hibernation)
swapon /dev/nvme0n1p3
```

### 3. Generate the Hardware Configuration

```bash
nixos-generate-config --root /mnt
rm /mnt/etc/nixos/configuration.nix   # the system is built from the flake only
```

On a machine with an NVIDIA GPU, add the driver settings to `/mnt/etc/nixos/hardware-configuration.nix` (bus IDs in decimal, see `lspci`; the iGPU line only on hybrid laptops):

```nix
  dotfiles.nvidia.enable = true;
  dotfiles.nvidia.prime.nvidiaBusId = "PCI:1:0:0";
  dotfiles.nvidia.prime.intelBusId = "PCI:0:2:0";
```

### 4. Clone the Repository

```bash
git clone https://github.com/lakape/dotfiles.git /mnt/home/bigl/dotfiles
cp /mnt/etc/nixos/hardware-configuration.nix /mnt/home/bigl/dotfiles/
git -C /mnt/home/bigl/dotfiles update-index --skip-worktree hardware-configuration.nix
```

### 5. Install, Set Passwords, Fix Ownership

```bash
nixos-install --no-root-passwd --flake /mnt/home/bigl/dotfiles#nixos

nixos-enter --root /mnt -c 'passwd root'
nixos-enter --root /mnt -c 'passwd bigl'
nixos-enter --root /mnt -c 'chown bigl:users /home/bigl && chmod 700 /home/bigl && chown -R bigl:users /home/bigl/dotfiles'

reboot
```

There is no default password: without the `passwd` steps nobody can log in.

---

## Daily Use

### Rebuilding and Updating

```bash
rebuild        # sudo nixos-rebuild switch --flake /home/bigl/dotfiles#nixos
update-flake   # cd /home/bigl/dotfiles && nix flake update
```

### Desktop Settings

- **KDE Plasma** settings (shortcuts, KWin, default browser) are declared in `plasma.nix` and applied on every rebuild. To turn settings changed in the GUI into Nix code, run `nix run github:nix-community/plasma-manager#rc2nix` and copy the relevant parts into `plasma.nix`.
- **Plasma layout:** `dotfiles/kde/plasma-org.kde.plasma.desktop-appletsrc` is installed before the first login, so Plasma never creates its default bottom panel. KOS provides the bar, dock and launcher.
- **KOS** settings (dock pins, tray order, launcher, appearance, window buttons) start from the files in `dotfiles/quickshell-kos` and `dotfiles/kos`. A rebuild only adds missing files, so changes made in the GUI are kept. KOS saves them only on this machine; to make them the default for new installations, copy them back into the repository and commit:
  ```bash
  ~/dotfiles/scripts/sync-desktop-to-repo.sh
  cd ~/dotfiles && git commit -am "chore: update desktop preferences" && git push
  ```
  The script only updates files that already exist in the repository. KOS does not accept links into the repository for these files, which is why they are copied.

### Helium Browser

Browser policies (search engine, bookmarks, HTTPS-only, Bitwarden) are set in `configuration.nix` under `programs.helium.policies`; `helium://policy` shows what is active. Bitwarden is installed automatically: for a self-hosted Vaultwarden, choose "Self-hosted" in the extension once and enter the server URL.

### SSH

The SSH server only accepts public keys (no passwords, no root login). Add the public keys that may log in to `users.users.bigl.openssh.authorizedKeys.keys` in `configuration.nix`. Never commit private keys. For connections from this machine, create a key with `ssh-keygen -t ed25519`.

### School Storage (HTL MEDT)

`/mnt/school/MEDT` is mounted on first access and unmounted when the network or VPN goes down. The credentials are not part of the repository; create them once per installation:

```bash
sudo install -m 600 /dev/null /etc/nixos/smb-secrets
sudoedit /etc/nixos/smb-secrets
```

Content:

```
username=<user>
password=<password>
domain=<domain>
```

### Machine-Specific Hardware Configuration

`hardware-configuration.nix` in your checkout belongs to this machine and is marked with `--skip-worktree`, so `git status` ignores it and it cannot be committed by accident. Nix still uses the local file. To make it visible to git again:

```bash
git -C ~/dotfiles update-index --no-skip-worktree hardware-configuration.nix
```

### Storage Maintenance

Old generations are removed weekly (`nix.gc`, older than 14 days) and the store is deduplicated weekly (`nix.optimise`). Manual cleanup:

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
├── configuration.nix          # System configuration
├── nvidia.nix                 # NVIDIA driver, enabled per machine by the installer
├── home.nix                   # Home Manager: user files, KOS defaults, shell aliases
├── plasma.nix                 # KDE Plasma settings (plasma-manager)
├── hardware-configuration.nix # Machine-specific, generated by the installer
├── dotfiles/
│   ├── kde/                   # Initial Plasma desktop layout (no panels)
│   ├── kos/                   # Default KOS window settings
│   ├── kos-share/             # KOS gallery wallpaper
│   ├── quickshell-kos/        # Default KOS shell state (dock, tray, launcher)
│   └── wallpapers/            # Desktop backgrounds
├── fonts/                     # Apple SF-Pro font collection
├── nextkde/                   # NextKDE / KOS desktop shell source tree
└── scripts/
    ├── install.sh             # Automated installation
    └── sync-desktop-to-repo.sh # Copies live KOS settings back into the repository
```
