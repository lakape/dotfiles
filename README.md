# Universal & 100% Reproducible NixOS & KOS Configuration (for ANY PC)

Dieses Repository enthält deine vollständige, zu **100 % reproduzierbare NixOS & NextKDE (KOS)** Desktop-Konfiguration in **einer einzigen zentralen `configuration.nix`**. Sie ist so konfiguriert, dass sie **auf jedem beliebigen Computer** (virtuelle Maschine, Laptop, PC mit Intel, AMD oder NVIDIA) identisch und stabil läuft.

---

## ⚡ Universelle 1-Klick-Installation auf JEDEM PC

Egal ob auf einem neuen Rechner, Laptop oder in einer Test-VM:
Starte einfach das NixOS-Live-Medium und führe diesen einzigen Befehl aus:

```bash
curl -sL https://raw.githubusercontent.com/lakape/dotfiles/master/scripts/install-on-new-pc.sh | bash
```

**Was das Skript vollautomatisch erledigt:**
1. Erkennt automatisch die Festplatte (NVMe, SATA, VirtIO) und partitioniert sie (512MB EFI + Root).
2. Formatiert die Partitionen und mountet sie nach `/mnt`.
3. Erfasst die Hardware des aktuellen PCs (`nixos-generate-config`).
4. Klont dieses Repository nach `/mnt/etc/dotfiles`.
5. Übernimmt die generierte `hardware-configuration.nix`.
6. Führt `nixos-install --flake /mnt/etc/dotfiles#nixos` aus.
7. Fragt direkt nach deinem Wunschpasswort für den Benutzer `bigl`.
   *(Falls manuell installiert wird: `sudo nixos-enter --root /mnt -c 'passwd bigl'` oder mit dem Fallback-Passwort `password` einloggen).*

Nach einem anschließenden `reboot` startet der PC direkt in deinen fertigen KOS-Desktop!

---

## 📁 Repository-Struktur (Flach und Eindeutig)

```
~/dotfiles/
├── flake.nix                  # Haupteinstiegspunkt (Flake-Target: nixos / default)
├── configuration.nix          # DIE einzige Konfiguration (KDE Plasma 6, KOS, Tools, Schriften, Shortcuts)
├── hardware-configuration.nix # Hardware-Scan der Zielmaschine (vom Installer generiert)
├── dotfiles/
│   ├── kde/                   # kwinrc, kglobalshortcutsrc, kdeglobals
│   └── kos/                   # window-appearance.json, window-buttons.json etc.
├── fonts/                     # Apple SF-Pro Schriftarten
└── scripts/
    ├── install-on-new-pc.sh   # Universeller 1-Klick-Installer für JEDEN Rechner
    ├── sync-desktop-to-repo.sh    # Holt GUI-Änderungen ins Git-Repo
    └── apply-desktop-from-repo.sh # Wendet Repo-Einstellungen auf ~/.config an
```

---

## 🖥️ Tolerante Grafiktreiber

In `configuration.nix` ist `videoDrivers = [ "nvidia" "modesetting" ];` gesetzt:
- Hat der Rechner eine **NVIDIA GPU**, lädt er die proprietären NVIDIA-Treiber mit PRIME-Offload.
- Hat der Rechner **keine NVIDIA GPU** (z. B. Intel/AMD-Laptop oder VM), fällt er automatisch und absturzfrei auf den Standard-Mesa/Modesetting-Treiber zurück.

---

## 🔄 Änderungen synchronisieren

Wenn du Shortcuts oder KOS-Einstellungen im GUI änderst:
1. `./scripts/sync-desktop-to-repo.sh` ausführen
2. `git commit -am "Update desktop shortcuts" && git push`
3. Auf jedem anderen Rechner einfach `git pull && rebuild` ausführen.
