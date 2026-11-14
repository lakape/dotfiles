# Universal & 100% Reproducible NixOS Flake (for ANY PC)

Dieses Repository enthält deine vollständige, zu **100 % reproduzierbare NixOS & NextKDE (KOS)** Desktop-Konfiguration. Sie ist so aufgebaut, dass sie **auf jedem beliebigen Computer** (virtuelle Maschine, Laptop, schwacher PC, Desktop mit Intel/AMD oder High-End Workstation mit NVIDIA) identisch installiert werden kann.

---

## 📁 Repository-Struktur

```
~/dotfiles/
├── flake.nix                          # Haupteinstiegspunkt (Profile: default/nixos & workstation)
├── hardware-configuration.nix         # Hardware-Scan der Zielmaschine (Platten, CPU, Boot)
├── modules/
│   ├── common.nix                     # Universelles Basissystem (KDE Plasma 6, KOS, Tools, PipeWire)
│   ├── home.nix                       # Home-Manager (KOS-Tokens, Tastaturkürzel, Shell-Aliase)
│   └── nvidia.nix                     # Optionales Profil für Rechner mit dedizierter NVIDIA-GPU
├── dotfiles/
│   ├── kde/                           # kwinrc, kglobalshortcutsrc, kdeglobals
│   └── kos/                           # window-appearance.json, window-buttons.json etc.
├── fonts/                             # Apple SF-Pro Schriftarten
└── scripts/
    ├── sync-desktop-to-repo.sh        # Holt aktuelle GUI-Änderungen ins Git-Repo
    └── apply-desktop-from-repo.sh     # Wendet Repo-Einstellungen auf ~/.config an
```

---

## 💻 Installation auf EINEM BELIEBIGEN PC (oder VM)

Egal ob auf einem neuen Laptop, einem schwächeren PC oder in einer Test-VM:

### 1. NixOS Live-Medium booten und Partitionen mounten
```bash
# Beispiel GPT (EFI 512M nach /mnt/boot, Root-Partition nach /mnt)
mount /dev/disk/by-label/nixos /mnt
mkdir -p /mnt/boot
mount /dev/disk/by-label/boot /mnt/boot
```

### 2. Hardware des PCs automatisch scannen
```bash
nixos-generate-config --root /mnt
```

### 3. Repository klonen & Hardware-Scan übernehmen
```bash
git clone https://github.com/lakape/dotfiles.git /mnt/etc/dotfiles
cp /mnt/etc/nixos/hardware-configuration.nix /mnt/etc/dotfiles/
```

### 4. Installation starten
```bash
# Auf jedem normalen Rechner (Intel / AMD / VM):
nixos-install --flake /mnt/etc/dotfiles

# Auf Rechnern mit dedizierter NVIDIA-GPU:
nixos-install --flake /mnt/etc/dotfiles#workstation
```

Nach einem `reboot` startet der Rechner direkt mit deinem exakt identischen KOS-Desktop, denselben Tastaturkürzeln, Farben, Schriftarten und Programmen!

---

## 🔄 Änderungen anpassen & synchronisieren

Wenn du Shortcuts oder KOS-Einstellungen im GUI änderst:
1. `./scripts/sync-desktop-to-repo.sh` ausführen
2. `git commit -am "Update desktop shortcuts" && git push`
3. Auf jedem anderen Rechner einfach `git pull && rebuild` ausführen.
