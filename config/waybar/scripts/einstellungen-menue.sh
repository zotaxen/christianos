#!/usr/bin/env bash
# =====================================================================
#  einstellungen-menue.sh  –  Einstellungs-Zentrale für ChristianOS
#  Ein Menü, das alle Einstellungen an einem Ort bündelt.
#  Gleicher Stil wie die anderen Menüs (~/.config/wofi/style.css)
#
#  Optional: nwg-displays (Monitore), nwg-look (Aussehen/Mauszeiger)
# =====================================================================

# ---------------------------------------------------------------------
#  EINSTELLUNGEN – hier kannst du alles anpassen
# ---------------------------------------------------------------------
TITEL="Einstellungen"
BREITE=420
HOEHE=560
TERMINAL="kitty"
EDITOR_BEFEHL="nano"
SKRIPTE="$HOME/.config/waybar/scripts"
DOTFILES="$HOME/dotfiles"
WALLPAPER_ORDNER="$HOME/Pictures/wallpaper"
WALLPAPER_MERKER="$HOME/.config/christianos/wallpaper"   # merkt sich den aktuellen Hintergrund
PLYMOUTH_SKRIPT="$HOME/plymouth-theme-erstellen.sh"

# Symbole (Nerd-Font-Codes)
ICON_NETZ=$''
ICON_BT=$''
ICON_TON=$''
ICON_MONITOR=$''
ICON_AUSSEHEN=$''
ICON_BILD=$''
ICON_START=$''
ICON_CODE=$''
ICON_TASTEN=$''
ICON_NEULADEN=$''
ICON_SICHERN=$''
ICON_UPDATE=$''

# ---------------------------------------------------------------------
#  HILFSFUNKTIONEN
# ---------------------------------------------------------------------
menue() {
    wofi --dmenu --prompt "$1" --width "$BREITE" --height "$HOEHE" \
         --insensitive --cache-file /dev/null
}

melden() {
    notify-send "Einstellungen" "$1"
}

# Datei im Terminal-Editor öffnen
bearbeiten() {
    setsid -f "$TERMINAL" -e "$EDITOR_BEFEHL" "$1"
}

# Befehl in einem Terminal ausführen; Fenster bleibt offen, bis Enter gedrückt wird
im_terminal() {
    setsid -f "$TERMINAL" -e bash -c "$1; echo; read -rp 'Fertig – Enter zum Schließen'"
}

# Ist ein Programm installiert?
gibt_es() {
    command -v "$1" >/dev/null
}

# Zeigt alle Bilder im Wallpaper-Ordner zur Auswahl an, gibt den Dateinamen zurück
bild_waehlen() {
    ls -1 "$WALLPAPER_ORDNER" 2>/dev/null \
        | grep -Ei '\.(gif|png|jpe?g|webp)$' \
        | menue "$1"
}

# ---------------------------------------------------------------------
#  1. Ein-/Ausschalter
# ---------------------------------------------------------------------
if pkill -x wofi; then
    exit 0
fi

# ---------------------------------------------------------------------
#  2. Menü zusammenbauen
# ---------------------------------------------------------------------
EINTRAEGE=""
EINTRAEGE+="$ICON_NETZ  Netzwerk"$'\n'
EINTRAEGE+="$ICON_BT  Bluetooth"$'\n'
EINTRAEGE+="$ICON_TON  Ton"$'\n'
gibt_es nwg-displays && EINTRAEGE+="$ICON_MONITOR  Monitore"$'\n'
gibt_es nwg-look     && EINTRAEGE+="$ICON_AUSSEHEN  Aussehen und Mauszeiger"$'\n'
EINTRAEGE+="$ICON_BILD  Hintergrund ändern"$'\n'
[ -x "$PLYMOUTH_SKRIPT" ] && EINTRAEGE+="$ICON_START  Startanimation ändern"$'\n'
EINTRAEGE+="$ICON_TASTEN  Tastenkürzel anzeigen"$'\n'
EINTRAEGE+="$ICON_CODE  Hyprland-Config bearbeiten"$'\n'
EINTRAEGE+="$ICON_CODE  Waybar-Config bearbeiten"$'\n'
EINTRAEGE+="$ICON_CODE  Waybar-Stil bearbeiten"$'\n'
EINTRAEGE+="$ICON_NEULADEN  Waybar neu laden"$'\n'
EINTRAEGE+="$ICON_SICHERN  Dotfiles sichern (GitHub)"$'\n'
EINTRAEGE+="$ICON_UPDATE  System aktualisieren"

AUSWAHL=$(printf '%s' "$EINTRAEGE" | menue "$TITEL")
[ -z "$AUSWAHL" ] && exit 0

# ---------------------------------------------------------------------
#  3. Auswahl ausführen
# ---------------------------------------------------------------------
case "$AUSWAHL" in
    *"Netzwerk"*)
        "$SKRIPTE/netzwerk-fenster.sh"
        ;;
    *"Bluetooth"*)
        pkill -x blueman-manager || setsid -f blueman-manager
        ;;
    *"Ton"*)
        pkill -x pavucontrol || setsid -f pavucontrol
        ;;
    *"Monitore"*)
        setsid -f nwg-displays
        ;;
    *"Aussehen"*)
        setsid -f nwg-look
        ;;
    *"Hintergrund ändern"*)
        DATEI=$(bild_waehlen "Hintergrund wählen")
        [ -z "$DATEI" ] && exit 0
        PFAD="$WALLPAPER_ORDNER/$DATEI"
        # Sofort anzeigen (awww-daemon starten, falls er nicht läuft)
        pgrep -x awww-daemon >/dev/null || { setsid -f awww-daemon; sleep 1; }
        awww img "$PFAD" --transition-type grow --transition-duration 2
        # Merken, damit der Hintergrund auch nach dem Neustart bleibt
        mkdir -p "$(dirname "$WALLPAPER_MERKER")"
        printf '%s\n' "$PFAD" > "$WALLPAPER_MERKER"
        melden "Hintergrund: $DATEI"
        ;;
    *"Startanimation ändern"*)
        DATEI=$(bild_waehlen "Startanimation wählen")
        [ -z "$DATEI" ] && exit 0
        # Braucht sudo (Passwort) – deshalb in einem Terminal
        im_terminal "$(printf '%q %q' "$PLYMOUTH_SKRIPT" "$WALLPAPER_ORDNER/$DATEI")"
        ;;
    *"Tastenkürzel"*)
        # Alle hl.bind-Zeilen aus der Config holen und lesbar anzeigen
        grep -E '^\s*hl\.bind\(' "$HOME/.config/hypr/hyprland.lua" \
            | sed -E 's/^\s*hl\.bind\(//; s/mainMod \.\. "/"SUPER/; s/\)\s*$//' \
            | menue "Tastenkürzel" >/dev/null
        ;;
    *"Hyprland-Config"*)
        bearbeiten "$HOME/.config/hypr/hyprland.lua"
        ;;
    *"Waybar-Config"*)
        bearbeiten "$HOME/.config/waybar/config.jsonc"
        ;;
    *"Waybar-Stil"*)
        bearbeiten "$HOME/.config/waybar/style.css"
        ;;
    *"Waybar neu laden"*)
        pkill waybar
        sleep 0.5
        setsid -f waybar
        melden "Waybar neu geladen"
        ;;
    *"Dotfiles sichern"*)
        im_terminal "
            mkdir -p '$DOTFILES/config' '$DOTFILES/scripts'
            cp -r ~/.config/hypr ~/.config/waybar ~/.config/wofi ~/.config/gtk-3.0 ~/.config/gtk-4.0 ~/.config/nwg-drawer ~/.config/christianos '$DOTFILES/config/' 2>/dev/null
            cp ~/.bashrc ~/.bash_profile '$DOTFILES/'
            cp '$PLYMOUTH_SKRIPT' '$DOTFILES/scripts/' 2>/dev/null
            cd '$DOTFILES' && git add . && git commit -m \"Sicherung \$(date '+%Y-%m-%d %H:%M')\" && git push
        "
        ;;
    *"System aktualisieren"*)
        im_terminal "sudo pacman -Syu"
        ;;
esac
