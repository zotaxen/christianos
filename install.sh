#!/bin/bash
# install.sh – kopiert die ChristianOS-Configs an die richtige Stelle.
# Vorhandene Configs werden vorher nach ~/.config-backup-<Datum> gesichert.

set -euo pipefail

QUELLE="$(cd "$(dirname "$0")" && pwd)"
SICHERUNG="$HOME/.config-backup-$(date +%F_%H-%M-%S)"

echo "ChristianOS wird installiert."
echo "Sicherung vorhandener Configs: $SICHERUNG"
mkdir -p "$SICHERUNG" "$HOME/.config"

for ordner in hypr waybar rofi kitty; do
    if [ -e "$HOME/.config/$ordner" ]; then
        cp -r "$HOME/.config/$ordner" "$SICHERUNG/"
    fi
    cp -r "$QUELLE/config/$ordner" "$HOME/.config/"
    echo "  ~/.config/$ordner installiert"
done

# Skripte ausführbar machen
chmod +x "$HOME/.config/rofi/"*.sh "$HOME/.config/waybar/scripts/"*.sh

# surface-monitor nach ~/.local/bin
if [ -f "$QUELLE/scripts/surface-monitor" ]; then
    mkdir -p "$HOME/.local/bin"
    cp "$QUELLE/scripts/surface-monitor" "$HOME/.local/bin/"
    chmod +x "$HOME/.local/bin/surface-monitor"
    echo "  ~/.local/bin/surface-monitor installiert"
fi

# Ordner für eigene Hintergrundbilder
mkdir -p "$HOME/Pictures/wallpaper"

echo
echo "Fertig. Lege eigene Bilder in ~/Pictures/wallpaper/ und starte Hyprland neu."
echo "Deine alten Configs liegen in: $SICHERUNG"
