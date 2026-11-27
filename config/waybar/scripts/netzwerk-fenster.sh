#!/usr/bin/env bash
# =====================================================================
#  netzwerk-fenster.sh  –  nmtui als dunkles, schwebendes Fenster
#  im ChristianOS-Design (Lila/Pink statt Blau/Rot).
#  Klick auf das Netzwerk-Symbol öffnet das Fenster, nochmal klicken
#  schließt es wieder.
# =====================================================================

# ---------------------------------------------------------------------
#  FARBEN – hier kannst du alles anpassen
# ---------------------------------------------------------------------
HINTERGRUND="#1e1e2e"   # Fensterhintergrund
SCHRIFT="#e0def4"       # Textfarbe
LILA="#9b59b6"          # Rahmen, Titel, Auswahl
PINK="#ff79c6"          # Hervorhebungen
DUNKEL2="#24243a"       # Schatten / zweite Hintergrundfarbe

# ---------------------------------------------------------------------
#  1. Ein-/Ausschalter: Ist das Fenster schon offen, schließen wir es.
#     ^ = "beginnt mit", damit sich das Skript nicht selbst beendet.
# ---------------------------------------------------------------------
if pgrep -f '^kitty --class netzwerk' >/dev/null; then
    pkill -f '^kitty --class netzwerk'
    exit 0
fi

# ---------------------------------------------------------------------
#  2. Farben für nmtui
#  nmtui (Bibliothek "newt") kennt nur die 8 Grundfarben des Terminals.
#  Deshalb sagen wir nmtui: "nimm black und magenta" – und weiter unten
#  sagen wir kitty, wie black und magenta in deinem Design aussehen.
# ---------------------------------------------------------------------
export NEWT_COLORS='
root=white,black
window=white,black
border=magenta,black
shadow=black,black
title=magenta,black
textbox=white,black
label=white,black
entry=white,brightblack
disentry=gray,black
button=white,brightblack
actbutton=white,magenta
compactbutton=white,black
checkbox=white,black
actcheckbox=white,magenta
listbox=white,black
actlistbox=white,magenta
sellistbox=white,brightblack
actsellistbox=white,magenta
helpline=white,black
roottext=white,black
emptyscale=,black
fullscale=,magenta
'

# ---------------------------------------------------------------------
#  3. kitty mit eigenen Farben starten
#  color0 = black, color8 = brightblack, color5/13 = magenta
# ---------------------------------------------------------------------
exec kitty --class netzwerk \
    -o background="$HINTERGRUND" \
    -o foreground="$SCHRIFT" \
    -o color0="$HINTERGRUND" \
    -o color8="$DUNKEL2" \
    -o color5="$LILA" \
    -o color13="$PINK" \
    -o color7="$SCHRIFT" \
    -o color15="#ffffff" \
    -o window_padding_width=20 \
    -o font_family="JetBrainsMono Nerd Font" \
    -o font_size=12 \
    -o background_opacity=0.92 \
    -e nmtui
