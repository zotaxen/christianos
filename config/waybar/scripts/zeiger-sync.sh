#!/usr/bin/env bash
# =====================================================================
#  zeiger-sync.sh  –  Überträgt Mauszeiger-Änderungen aus nwg-look
#  automatisch auf Hyprland.
#
#  nwg-look speichert den Zeiger in den GTK-Einstellungen (gsettings).
#  Hyprland liest die aber nicht. Dieses Skript läuft im Hintergrund,
#  bemerkt jede Änderung und stellt Hyprland sofort mit um – und trägt
#  den Zeiger dauerhaft in die hyprland.lua ein.
#
#  Wird per Autostart in der hyprland.lua gestartet.
# =====================================================================

CONF="$HOME/.config/hypr/hyprland.lua"

anwenden() {
    local NAME GROESSE
    NAME=$(gsettings get org.gnome.desktop.interface cursor-theme | tr -d "'")
    GROESSE=$(gsettings get org.gnome.desktop.interface cursor-size)
    [ -z "$NAME" ] && return

    # Sofort in Hyprland
    hyprctl setcursor "$NAME" "$GROESSE" >/dev/null

    # Dauerhaft in der hyprland.lua
    sed -i -E "s/(hl\.env\(\"XCURSOR_THEME\",\s*\")[^\"]*/\1$NAME/" "$CONF"
    sed -i -E "s/(hl\.env\(\"(X|HYPR)CURSOR_SIZE\",\s*\")[0-9]*/\1$GROESSE/" "$CONF"

    # Standard für alle übrigen Programme
    mkdir -p "$HOME/.local/share/icons/default"
    printf '[Icon Theme]\nInherits=%s\n' "$NAME" > "$HOME/.local/share/icons/default/index.theme"
}

# Läuft schon eine Kopie? Dann nicht doppelt starten.
if [ "$(pgrep -cf '^bash .*zeiger-sync.sh')" -gt 1 ]; then
    exit 0
fi

# Einmal beim Start anwenden ...
anwenden

# ... und dann auf jede Änderung warten (cursor-theme oder cursor-size)
gsettings monitor org.gnome.desktop.interface | while read -r schluessel _; do
    case "$schluessel" in
        cursor-theme:|cursor-size:) anwenden ;;
    esac
done
