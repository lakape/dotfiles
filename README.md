# Universal & 100% Reproducible NixOS & KOS Flake (for ANY PC)

Dieses Repository enthält deine vollständige, zu **100 % reproduzierbare NixOS & NextKDE (KOS)** Desktop-Konfiguration. Sie ist so gebaut, dass sie **auf jedem beliebigen Computer** (virtuelle Maschine, Laptop, schwacher PC, Gaming-Desktop mit Intel, AMD oder NVIDIA) identisch installiert werden kann.

---

## ⚡ Universelle 1-Klick-Installation auf JEDEM PC

Egal ob auf einem neuen Laptop, einem schwächeren PC oder in einer Test-VM:
Starte einfach das NixOS-Live-Medium und führe diesen einzigen Befehl aus:

```bash
curl -sL https://raw.githubusercontent.com/lakape/dotfiles/master/scripts/install-on-new-pc.sh | bash
```

**Was das Skript vollautomatisch erledigt:**
1. Listet alle Festplatten auf (NVMe, SATA, VirtIO) und lässt dich das Ziellaufwerk auswählen.
2. Erstellt saubere GPT-Partitionen (512MB EFI + Root) und formatiert sie.
3. Mountet alles nach `/mnt` und scannt die Hardware des PCs (`nixos-generate-config`).
4. Klont dieses Repository nach `/mnt/etc/dotfiles`.
5. **Automatische Hardware-Erkennung:** Erkennt automatisch, ob eine dedizierte NVIDIA-GPU verbaut ist (wählt dann `#workstation` mit PRIME-Offload) oder Standard-Grafik wie Intel/AMD/VM vorliegt (wählt `#nixos`).
6. Führt `nixos-install` komplett durch.

Nach einem anschließenden `reboot` startet der PC direkt in deinen fertigen KOS-Desktop!

---

## 📁 Repository-Struktur

```
~/dotfiles/
├── flake.nix                          # Haupteinstiegspunkt (Profile: default/nixos & workstation)
├── hardware-configuration.nix         # Hardware-Scan der Zielmaschine (Platten, CPU, Boot)
├── modules/
│   ├── common.nix                     # Universelles Basissystem (KDE Plasma 6, KOS, Tools, PipeWire)
│   ├── home.nix                       # Home-Manager (KOS-Tokens, Tastaturkürzel, Shell-Aliase)
│   └── nvidia.nix                     # Optionales Modul für Rechner mit dedizierter NVIDIA-GPU
├── dotfiles/
│   ├── kde/                           # kwinrc, kglobalshortcutsrc, kdeglobals
│   └── kos/                           # window-appearance.json, window-buttons.json etc.
├── fonts/                             # Apple SF-Pro Schriftarten
└── scripts/
    ├── install-on-new-pc.sh           # Universeller 1-Klick-Installer für jeden Rechner
    ├── sync-desktop-to-repo.sh        # Holt aktuelle GUI-Änderungen ins Git-Repo
    └── apply-desktop-from-repo.sh     # Wendet Repo-Einstellungen auf ~/.config an
```

---

## 🔄 Änderungen anpassen & synchronisieren

Wenn du Shortcuts oder KOS-Einstellungen im GUI änderst:
1. `./scripts/sync-desktop-to-repo.sh` ausführen
2. `git commit -am "Update desktop shortcuts" && git push`
3. Auf jedem anderen Rechner einfach `git pull && rebuild` ausführen.
