#!/usr/bin/env bash
# =====================================================================
#  power-menue.sh  –  Herunterfahren-Menü für Waybar (mit wofi)
#  Sperren, Abmelden, Standby, Neustart, Herunterfahren.
#  Gleicher Stil wie die anderen Menüs (~/.config/wofi/style.css)
#
#  Braucht: wofi   (optional: hyprlock zum Sperren)
# =====================================================================

# ---------------------------------------------------------------------
#  EINSTELLUNGEN – hier kannst du alles anpassen
# ---------------------------------------------------------------------
TITEL="Ausschalten"
BREITE=320
HOEHE=290
NACHFRAGEN=1          # 1 = bei Neustart/Herunterfahren nochmal fragen, 0 = sofort

# Symbole (Nerd-Font-Codes)
ICON_SPERREN=$''      # Schloss
ICON_ABMELDEN=$''     # Tür mit Pfeil
ICON_STANDBY=$''      # Mond
ICON_NEUSTART=$''     # Kreispfeil
ICON_AUS=$''          # Power

# ---------------------------------------------------------------------
#  HILFSFUNKTIONEN
# ---------------------------------------------------------------------
menue() {
    wofi --dmenu \
         --prompt "$1" \
         --width "$BREITE" \
         --height "$2" \
         --cache-file /dev/null
}

# Fragt "Wirklich …?" – gibt 0 (ja) oder 1 (nein) zurück
wirklich() {
    [ "$NACHFRAGEN" -eq 0 ] && return 0
    ANTWORT=$(printf '%s\n' "Ja, $1" "Abbrechen" | menue "Wirklich $1?" 160)
    [[ "$ANTWORT" == Ja* ]]
}

# ---------------------------------------------------------------------
#  1. Ein-/Ausschalter: Läuft wofi schon, schließen wir es nur.
# ---------------------------------------------------------------------
if pkill -x wofi; then
    exit 0
fi

# ---------------------------------------------------------------------
#  2. Menü zusammenbauen
# ---------------------------------------------------------------------
EINTRAEGE=""
# "Sperren" nur anzeigen, wenn hyprlock installiert ist
command -v hyprlock >/dev/null && EINTRAEGE+="$ICON_SPERREN  Sperren"$'\n'
EINTRAEGE+="$ICON_ABMELDEN  Abmelden"$'\n'
EINTRAEGE+="$ICON_STANDBY  Standby"$'\n'
EINTRAEGE+="$ICON_NEUSTART  Neustart"$'\n'
EINTRAEGE+="$ICON_AUS  Herunterfahren"

AUSWAHL=$(printf '%s' "$EINTRAEGE" | menue "$TITEL" "$HOEHE")
[ -z "$AUSWAHL" ] && exit 0

# ---------------------------------------------------------------------
#  3. Auswahl ausführen
# ---------------------------------------------------------------------
case "$AUSWAHL" in
    *"Sperren"*)
        hyprlock
        ;;
    *"Abmelden"*)
        wirklich "abmelden" && loginctl terminate-session "$XDG_SESSION_ID"
        ;;
    *"Standby"*)
        systemctl suspend
        ;;
    *"Neustart"*)
        wirklich "neu starten" && systemctl reboot
        ;;
    *"Herunterfahren"*)
        wirklich "herunterfahren" && systemctl poweroff
        ;;
esac
