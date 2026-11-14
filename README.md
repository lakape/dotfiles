# Modular & 100% Reproducible NixOS Flake

Dieses Repository enthält die vollständige, reproduzierbare Konfiguration für:
- **Workstation** (`#workstation` / `#nixos`): Hauptrechner mit Intel i9 & NVIDIA RTX 4060 Mobile (PRIME Offload)
- **Secondary PC** (`#secondary`): Schwächerer Zweitrechner mit nativer Intel/AMD Open-Source Grafik (Mesa KMS)
- **NextKDE (KOS)**: Declarativer Desktop Shell auf Basis von Plasma 6 und Quickshell
- **Home-Manager**: Automatische Konfiguration von Tastaturkürzeln, Desktop-Tokens und Shell-Profilen

---

## 📁 Repository-Struktur

```
~/dotfiles/
├── flake.nix                          # Haupteinstiegspunkt für alle Hosts & Inputs
├── modules/
│   ├── common.nix                     # Geteiltes Basissystem (KDE, Audio, KOS, Tools, Chromium)
│   └── home.nix                       # Home-Manager Benutzerprofil (Shortcuts, KOS-Tokens, Aliase)
├── hosts/
│   ├── workstation/                   # Hardware & GPU-Konfiguration des Hauptrechners
│   │   ├── default.nix
│   │   └── hardware-configuration.nix
│   └── secondary/                     # Hardware-Profil für den leistungsschwächeren PC
│       ├── default.nix
│       └── hardware-configuration.nix
├── dotfiles/
│   ├── kde/                           # KWin & KDE Desktop-Vorlagen (kwinrc, shortcuts)
│   └── kos/                           # KOS Window & App-Regeln
├── fonts/                             # Apple SF-Pro Schriftarten
├── scripts/
│   ├── sync-desktop-to-repo.sh        # Holt aktuelle GUI-Änderungen ins Git-Repo
│   └── apply-desktop-from-repo.sh     # Wendet Einstellungen aus dem Repo auf ~/.config an
└── nextkde/                           # KOS Desktop Shell Source & Nix-Module
```

---

## 🚀 Schnellanleitung: Diesen Rechner aktualisieren

```bash
# Auf diesem Rechner das System anwenden:
sudo nixos-rebuild switch --flake ~/dotfiles#workstation

# Oder über den eingerichteten Alias:
rebuild-workstation
```

---

## 💻 Installation auf dem schwächeren Zweit-PC

Auf dem neuen / schwächeren Computer lässt sich das System in 4 einfachen Schritten komplett identisch aufsetzen:

### 1. Minimales NixOS-Live-Medium booten und Platten partitionieren
Formatieren (z. B. ext4 oder btrfs) und mounten nach `/mnt` sowie EFI nach `/mnt/boot`.

### 2. Hardware-Konfiguration generieren
```bash
nixos-generate-config --root /mnt
```

### 3. Repository klonen und Hardware-Scan einfügen
```bash
git clone <DEIN_REPO_URL> /mnt/etc/dotfiles
cp /mnt/etc/nixos/hardware-configuration.nix /mnt/etc/dotfiles/hosts/secondary/hardware-configuration.nix
```

### 4. Installation starten
```bash
nixos-install --flake /mnt/etc/dotfiles#secondary
```

Nach dem ersten Neustart bootet der schwächere Computer direkt in denselben KOS-Desktop mit denselben Tastaturkürzeln, App-Tokens und Tools!

---

## 🔄 Desktop-Einstellungen anpassen und synchronisieren

Wenn du Shortcuts oder KOS-Einstellungen im GUI änderst:
1. `./scripts/sync-desktop-to-repo.sh` ausführen
2. `git commit -am "Update desktop shortcuts"`
3. Auf dem zweiten Rechner `git pull && rebuild-secondary`
