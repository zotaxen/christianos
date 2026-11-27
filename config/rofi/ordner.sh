#!/bin/bash
# ChristianOS App-Menü: alle Apps auf einen Blick, sortierbar in eigene Ordner

# Läuft das Menü schon? Dann schließen (Klick auf Start = auf/zu)
LOCK="${XDG_RUNTIME_DIR:-/tmp}/christianos-ordner.pid"
if [ -f "$LOCK" ] && kill -0 "$(cat "$LOCK")" 2>/dev/null; then
    kill "$(cat "$LOCK")"; pkill -x rofi; rm -f "$LOCK"; exit 0
fi
[ "$1" = "--zu" ] && exit 1          # --zu: nur schließen, nichts öffnen
echo $$ > "$LOCK"
trap 'rm -f "$LOCK"' EXIT

ORDNER_DIR="$HOME/.config/christianos/ordner"
ICON_DIR="$ORDNER_DIR/.icons"          # pro Ordner ein eigenes Icon
mkdir -p "$ORDNER_DIR" "$ICON_DIR"
APP_DIRS=("$HOME/.local/share/applications" "/usr/share/applications" "/var/lib/flatpak/exports/share/applications" "$HOME/.local/share/flatpak/exports/share/applications")

# Pfad zur .desktop-Datei einer App finden
pfad() {
    for d in "${APP_DIRS[@]}"; do
        if [ -f "$d/$1" ]; then echo "$d/$1"; return; fi
    done
}

# Eine App als Zeile "id|Name|Icon|Suchwörter" ausgeben
# Suchwörter = Beschreibung, Stichwörter und Kategorien aus der .desktop-Datei
zeile() {
    local p; p=$(pfad "$1")
    [ -n "$p" ] || return
    awk -v id="$1" '
        /^\[/ { abschnitt = $0; next }
        abschnitt == "[Desktop Entry]" && index($0, "=") {
            k = substr($0, 1, index($0, "=") - 1)
            if (!(k in v)) v[k] = substr($0, index($0, "=") + 1)
        }
        END {
            m = v["GenericName"] " " v["GenericName[de]"] " " v["Keywords"] " " v["Keywords[de]"] " " v["Categories"]
            n = v["Name"]
            gsub(/[;|]/, " ", m); gsub(/\|/, " ", n)
            print id "|" n "|" v["Icon"] "|" m
        }' "$p"
}

# rofi-Eintrag mit Icon und unsichtbaren Suchwörtern ausgeben: eintrag Name Icon Suchwörter
eintrag() { printf '%s\0icon\x1f%s\x1fmeta\x1f%s\n' "$1" "$2" "$3"; }

# Alle sichtbaren Apps, nach Namen sortiert (optional nur eine Kategorie, z. B. Game)
# Pro App zählt nur die erste gefundene Datei (eigene Kopien in ~/.local haben Vorrang)
alle_apps() {
    local -A gesehen
    local d f id
    for d in "${APP_DIRS[@]}"; do
        for f in "$d"/*.desktop; do
            [ -f "$f" ] || continue
            id=$(basename "$f")
            [ -n "${gesehen[$id]}" ] && continue
            gesehen[$id]=1
            grep -qE '^(NoDisplay|Hidden)=true' "$f" && continue
            [ -n "$1" ] && ! grep -q "^Categories=.*$1;" "$f" && continue
            echo "$id"
        done
    done | while read -r id; do zeile "$id"; done | sort -t'|' -k2 -f
}

# Apps in einem Ordner
ordner_apps() {
    while read -r id; do zeile "$id"; done < "$ORDNER_DIR/$1"
}

# Icon eines Ordners (Standard: folder)
ordner_icon() { cat "$ICON_DIR/$1" 2>/dev/null || echo folder; }

# Suchwörter eines Ordners = Namen und Suchwörter aller Apps darin
ordner_suchwoerter() { ordner_apps "$1" | cut -d'|' -f2,4 | tr '|\n' '  '; }

# Alle Ordner als rofi-Einträge (optional: einen Ordner auslassen)
ordner_liste() {
    local name
    for f in "$ORDNER_DIR"/*; do
        [ -f "$f" ] || continue
        name=$(basename "$f")
        [ "$name" = "$1" ] && continue
        eintrag "$name" "$(ordner_icon "$name")" "$(ordner_suchwoerter "$name")"
    done
}

# Icon aus deinem Icon-Theme auswählen (Ordner- und App-Kategorie-Icons)
icon_waehlen() {
    local icons i
    mapfile -t icons < <(find /usr/share/icons/candy-icons "$HOME/.local/share/icons/candy-icons" \
        \( -name 'folder*' -o -name 'applications-*' -o -name 'user-*' \) 2>/dev/null \
        | xargs -rn1 basename | sed 's/\.[^.]*$//' | sort -u)
    [ ${#icons[@]} -eq 0 ] && icons=(folder folder-documents folder-download folder-music folder-pictures folder-videos applications-games applications-internet applications-development)
    i=$(for ic in "${icons[@]}"; do printf '%s\0icon\x1f%s\n' "$ic" "$ic"; done \
        | rofi -dmenu -i -p "Icon für $1" -format i)
    [ -n "$i" ] && echo "${icons[$i]}"
}

# Eine App aus allen Ordnern austragen
aus_allen_entfernen() {
    for f in "$ORDNER_DIR"/*; do
        [ -f "$f" ] || continue
        grep -vxF "$1" "$f" > "$f.tmp"; mv "$f.tmp" "$f"
    done
}

# Liste "id|Name|Icon" in rofi zeigen, gewählte id ausgeben
app_waehlen() {
    mapfile -t z
    if [ ${#z[@]} -eq 0 ]; then notify-send "Ordner" "Keine Apps zur Auswahl"; return; fi
    local i
    i=$(for x in "${z[@]}"; do
            IFS='|' read -r _ name icon meta <<< "$x"
            eintrag "$name" "$icon" "$meta"
        done | rofi -dmenu -i -p "$1" -format i)
    [ -n "$i" ] && echo "${z[$i]%%|*}"
}

# Wie app_waehlen, aber mehrere Apps auf einmal (Shift+Enter markiert), gibt je Zeile eine id aus
apps_waehlen() {
    mapfile -t z
    if [ ${#z[@]} -eq 0 ]; then notify-send "Ordner" "Keine Apps zur Auswahl"; return; fi
    for x in "${z[@]}"; do
        IFS='|' read -r _ name icon meta <<< "$x"
        eintrag "$name" "$icon" "$meta"
    done | rofi -dmenu -i -multi-select -p "$1" -format i \
               -mesg "Shift+Enter: markieren  ·  Enter: fertig" \
         | while read -r i; do echo "${z[$i]%%|*}"; done
}

# Einen Ordner öffnen: Apps starten, hinzufügen, verschieben, entfernen
# Rückgabe 0 = App gestartet (Menü zu), 1 = zurück ins Hauptmenü
# Optional $2 = Suchbegriff, der beim ersten Anzeigen schon eingetragen ist
ordner_oeffnen() {
    local ordner="$1" vorfilter="$2" z n i id ids ziel ic
    while true; do
        mapfile -t z < <(ordner_apps "$ordner")
        n=${#z[@]}
        i=$( {
            for x in "${z[@]}"; do
                IFS='|' read -r _ name icon meta <<< "$x"
                eintrag "$name" "$icon" "$meta"
            done
            printf '%s\0icon\x1f%s\n' "+ App hinzufügen" "list-add" "App verschieben" "document-send" "App entfernen" "list-remove" "Icon ändern" "preferences-desktop-icons" "← Zurück" "go-previous"
        } | rofi -dmenu -i -p "$ordner" -format i ${vorfilter:+-filter "$vorfilter"})
        vorfilter=""                                # nur beim ersten Mal vorausfüllen

        [ -z "$i" ] && return 1                     # Esc: zurück
        if [ "$i" -lt "$n" ]; then                  # App angeklickt: starten
            id="${z[$i]%%|*}"; gtk-launch "${id%.desktop}"; return 0
        fi

        case $((i - n)) in
            0)  # Apps hinzufügen (mehrere möglich)
                ids=$(alle_apps | apps_waehlen "Zu „$ordner“ hinzufügen")
                while read -r id; do
                    [ -n "$id" ] || continue
                    aus_allen_entfernen "$id"
                    echo "$id" >> "$ORDNER_DIR/$ordner"
                done <<< "$ids" ;;
            1)  # Apps in einen anderen Ordner verschieben (mehrere möglich)
                [ "$n" -eq 0 ] && { notify-send "Ordner" "Der Ordner ist leer"; continue; }
                ids=$(printf '%s\n' "${z[@]}" | apps_waehlen "Welche Apps verschieben?")
                [ -z "$ids" ] && continue
                ziel=$(ordner_liste "$ordner" | rofi -dmenu -i -p "Wohin?")
                [ -z "$ziel" ] && continue
                while read -r id; do
                    [ -n "$id" ] || continue
                    aus_allen_entfernen "$id"
                    echo "$id" >> "$ORDNER_DIR/$ziel"
                done <<< "$ids"
                notify-send "Ordner" "$(grep -c . <<< "$ids") App(s) nach „$ziel“ verschoben" ;;
            2)  # Apps aus diesem Ordner entfernen (mehrere möglich)
                [ "$n" -eq 0 ] && { notify-send "Ordner" "Der Ordner ist leer"; continue; }
                ids=$(printf '%s\n' "${z[@]}" | apps_waehlen "Welche Apps entfernen?")
                while read -r id; do
                    [ -n "$id" ] && aus_allen_entfernen "$id"
                done <<< "$ids" ;;
            3)  # Icon des Ordners ändern
                ic=$(icon_waehlen "$ordner")
                [ -n "$ic" ] && echo "$ic" > "$ICON_DIR/$ordner" ;;
            4)  return 1 ;;                         # Zurück
        esac
    done
}

# Apps eines Ordners, die zu einem Suchbegriff passen (jedes Wort muss vorkommen, wie bei rofi)
ordner_treffer() {
    local treffer wort
    treffer=$(ordner_apps "$1")
    for wort in $2; do treffer=$(grep -iF -- "$wort" <<< "$treffer"); done
    grep . <<< "$treffer"
}

# ---------- Suchmodus (--suche): alle Apps, auch die in Ordnern ----------
if [ "$1" = "--suche" ]; then
    id=$(alle_apps | app_waehlen "Suche")
    [ -n "$id" ] && gtk-launch "${id%.desktop}"
    exit 0
fi

# ---------- Hauptmenü: Ordner + alle Apps, die in keinem Ordner sind ----------
while true; do
    T=(); W=(); L=()        # Typ, Wert, Anzeige ("Name|Icon|Suchwörter") je Eintrag

    T+=(spiele); W+=(""); L+=("Spiele|applications-games|games game spiel")

    for f in "$ORDNER_DIR"/*; do                    # deine Ordner
        [ -f "$f" ] || continue
        n=$(basename "$f")
        T+=(ordner); W+=("$n"); L+=("$n|$(ordner_icon "$n")|$(ordner_suchwoerter "$n")")
    done

    einsortiert=$(cat "$ORDNER_DIR"/* 2>/dev/null)  # Apps, die schon in Ordnern liegen
    while IFS='|' read -r id name icon meta; do    # alle anderen Apps direkt zeigen
        grep -qxF "$id" <<< "$einsortiert" && continue
        T+=(app); W+=("$id"); L+=("$name|$icon|$meta")
    done < <(alle_apps)

    T+=(neu loeschen); W+=("" ""); L+=("+ Neuer Ordner|folder-new|" "Ordner löschen|user-trash|")

    # -format 'i f' = Nummer des Eintrags, Leerzeichen, das was du getippt hast
    ausgabe=$(for x in "${L[@]}"; do IFS='|' read -r name icon meta <<< "$x"; eintrag "$name" "$icon" "$meta"; done \
        | rofi -dmenu -i -p "Apps" -format 'i f')

    [ -z "$ausgabe" ] && exit 0                     # Esc im Hauptmenü: zu
    i=${ausgabe%% *}                                # alles vor dem ersten Leerzeichen
    suche=""
    [[ "$ausgabe" == *" "* ]] && suche=${ausgabe#* }  # alles danach (falls vorhanden)

    case "${T[$i]}" in
        app)    gtk-launch "${W[$i]%.desktop}"; exit 0 ;;
        ordner)
            # Intelligentes Enter: über die Suche gefunden?
            if [ -n "$suche" ]; then
                treffer=$(ordner_treffer "${W[$i]}" "$suche")
                if [ "$(grep -c . <<< "$treffer")" -eq 1 ]; then   # genau eine App passt: direkt starten
                    id=${treffer%%|*}; gtk-launch "${id%.desktop}"; exit 0
                fi
                ordner_oeffnen "${W[$i]}" "$suche" && exit         # mehrere: Ordner mit Suchbegriff öffnen
            else
                ordner_oeffnen "${W[$i]}" && exit
            fi ;;
        spiele)
            id=$(alle_apps Game | app_waehlen "Spiele")
            [ -n "$id" ] && { gtk-launch "${id%.desktop}"; exit 0; } ;;
        neu)
            name=$(rofi -dmenu -p "Name des Ordners" -theme-str 'listview { enabled: false; }' < /dev/null)
            name=${name//\//-}
            if [ -n "$name" ]; then
                touch "$ORDNER_DIR/$name"
                ordner_oeffnen "$name" && exit      # gleich hinein, Apps hinzufügen
            fi ;;
        loeschen)
            ziel=$(ordner_liste | rofi -dmenu -i -p "Welchen Ordner löschen?")
            [ -n "$ziel" ] && rm -f "$ORDNER_DIR/$ziel" "$ICON_DIR/$ziel" && notify-send "Ordner" "„$ziel“ gelöscht, die Apps sind wieder im Hauptmenü" ;;
    esac
done
