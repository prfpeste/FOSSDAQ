#!/bin/bash
#
# find_arduino.sh
# Findet den seriellen Port eines Arduino (auch Clones), indem es
# über die serielle Schnittstelle "serveID" sendet und die Antwort prüft.
#
# Ausgabe: PORT<TAB>EMPFANGENE_NACHRICHT   (eine Zeile pro gefundenem Gerät)
#
# Nutzung:
#   ./find_arduino.sh            -> gibt Port + Nachricht des ersten Treffers aus
#                                    z.B. "/dev/ttyACM0    ID1130"
#   ./find_arduino.sh -v         -> ausführliche Ausgabe (Debugging)
#   ./find_arduino.sh -a         -> gibt ALLE gefundenen Arduino-Ports (+ Nachricht) aus
#   ./find_arduino.sh -s         -> legt zusätzlich für jeden Treffer einen Symlink an,
#                                    z.B. /dev/arduino/ID1130 -> /dev/ttyACM0
#                                    (braucht meist sudo, da unter /dev geschrieben wird)
#   ./find_arduino.sh -d DIR     -> Zielverzeichnis für die Symlinks (Standard: /dev/arduino)
#                                    impliziert -s

set -uo pipefail

# ==========================================================================
# ANPASSEN: Liste der bekannten IDs, die ein Arduino/Board zurückliefert.
# Einfach neue Einträge hinzufügen/entfernen.
# Die Antwort endet immer mit einer 5-stelligen Zahl (z.B. Seriennummer),
# die für den Vergleich automatisch abgeschnitten wird -> hier nur die
# eigentliche ID ohne die Zahl eintragen.
# ==========================================================================
KNOWN_IDS=(
    "ID"
    # weitere IDs hier ergänzen, z.B.:
    # "MeinSensorBoard"
)

BAUDRATE=9600      # ANPASSEN: an die Baudrate deines Sketches
IDENTIFY_CMD='serveID'
TIMEOUT_SEC=2       # wie lange auf Antwort gewartet wird
BOOT_WAIT_SEC=2     # viele Boards resetten beim Öffnen des Ports (DTR) -> Bootzeit abwarten

VERBOSE=0
LIST_ALL=0
MAKE_SYMLINKS=0
SYMLINK_DIR="/dev/arduino"   # ANPASSEN: Zielverzeichnis für die Symlinks
LAST_RESPONSE=""   # wird von check_port() mit der empfangenen Rohantwort befüllt

while getopts "vasd:p" opt; do
  case $opt in
    v) VERBOSE=1 ;;
    a) LIST_ALL=1 ;;
    s) MAKE_SYMLINKS=1 ;;
    d) MAKE_SYMLINKS=1; SYMLINK_DIR="$OPTARG" ;;
    p) SINGLE_PORT="$OPTARG" ;;
    *) echo "Unbekannte Option"; exit 1 ;;
  esac
done

log() {
    if [ "$VERBOSE" -eq 1 ]; then
        echo "$@" >&2
    fi
}

check_port() {
    local dev="$1"

    if [ ! -w "$dev" ]; then
        log "  -> keine Schreibrechte auf $dev, überspringe (evtl. sudo nötig oder dialout-Gruppe)"
        return 1
    fi

    # Port konfigurieren: Baudrate, raw mode (keine Verarbeitung/Echo)
    if ! stty -F "$dev" "$BAUDRATE" raw -echo cs8 -cstopb -parenb 2>/dev/null; then
        log "  -> stty fehlgeschlagen auf $dev"
        return 1
    fi

    # WICHTIG: Den Port nur EINMAL öffnen und die Verbindung für Schreiben
    # UND Lesen offenhalten (File-Descriptor 3). Würde man stattdessen
    # mehrfach hintereinander öffnen (z.B. einmal zum Schreiben, einmal
    # zum Lesen), lösen viele Boards bei JEDEM Öffnen einen Reset aus
    # (DTR-Toggle) -> man schreibt/liest dann evtl. mitten im Neustart
    # des Boards und bekommt nie eine passende Antwort.
    if ! exec 3<>"$dev"; then
        log "  -> konnte $dev nicht öffnen"
        return 1
    fi

    # Nach dem Öffnen resetten viele Boards (Uno, Nano mit CH340, Leonardo...).
    # Kurz warten, bis der Sketch wieder läuft.
    sleep "$BOOT_WAIT_SEC"

    # Eingangspuffer leeren (alte Boot-Meldungen etc. verwerfen)
    timeout 0.3 dd if=/proc/self/fd/3 of=/dev/null bs=1 2>/dev/null

    # Befehl senden
    printf '%s\n' "$IDENTIFY_CMD" >&3

    # Antwort mit Timeout lesen (erste Zeile reicht)
    local response
    response=$(timeout "$TIMEOUT_SEC" head -n1 <&3)

    # Verbindung schließen
    exec 3<&-
    exec 3>&-

    # Zeilenumbrüche/Leerzeichen am Rand entfernen
    response="$(echo "$response" | tr -d '\r\n' | xargs)"

    log "  -> Antwort (roh): '$response'"

    LAST_RESPONSE="$response"

    if [ -z "$response" ]; then
        log "  -> keine Antwort erhalten (Timeout)"
        return 1
    fi

    # Angehängte Zahl (beliebig viele Ziffern, z.B. Seriennummer/ID-Nummer)
    # am Ende für den Vergleich abschneiden.
    local id_part
    id_part=$(echo "$response" | sed -E 's/[0-9]+$//')

    log "  -> ID ohne Zahl: '$id_part'"

    for known in "${KNOWN_IDS[@]}"; do
        if [ "$id_part" = "$known" ]; then
            log "  -> passt zu bekannter ID '$known'"
            return 0
        fi
    done

    return 1
}

# Legt unter $SYMLINK_DIR einen Symlink an, der auf den seriellen Port zeigt.
# Der Name des Links wird aus der vom Arduino gesendeten Antwort gebildet
# (z.B. "ID1130"), damit man das Board unabhängig vom zufällig vergebenen
# /dev/ttyACM*-Namen ansprechen kann.
create_symlink() {
    local dev="$1"
    local response="$2"

    # Antwort in einen für Dateinamen/Symlinks sicheren String umwandeln:
    # nur Buchstaben, Ziffern, '_', '.', '-' erlauben, alles andere -> '_'
    local safe_name
    safe_name=$(printf '%s' "$response" | tr -c 'A-Za-z0-9_.-' '_')

    if [ -z "$safe_name" ]; then
        log "  -> konnte keinen gültigen Symlink-Namen aus '$response' erzeugen, überspringe"
        return 1
    fi

    if ! mkdir -p "$SYMLINK_DIR" 2>/dev/null; then
        log "  -> konnte $SYMLINK_DIR nicht anlegen (evtl. sudo nötig)"
        return 1
    fi

    local link="$SYMLINK_DIR/$safe_name"
    if ln -sf "$dev" "$link" 2>/dev/null; then
        log "  -> Symlink erstellt: $link -> $dev"
    else
        log "  -> konnte Symlink $link nicht erstellen (evtl. sudo nötig, z.B. mit sudo starten)"
        return 1
    fi
}

FOUND_PORTS=()
FOUND_RESPONSES=()

if [ -n "${SINGLE_PORT:-}" ]; then
    CANDIDATES=("$SINGLE_PORT")
else
    shopt -s nullglob
    CANDIDATES=(/dev/ttyACM* /dev/ttyUSB*)
    shopt -u nullglob
fi

if [ ${#CANDIDATES[@]} -eq 0 ]; then
    echo "Keine seriellen USB-Geräte gefunden (weder /dev/ttyACM* noch /dev/ttyUSB*)." >&2
    exit 1
fi

for dev in "${CANDIDATES[@]}"; do
    log "Prüfe $dev ..."
    if check_port "$dev"; then
        log "  -> Arduino erkannt auf $dev (Antwort: '$LAST_RESPONSE')"
        FOUND_PORTS+=("$dev")
        FOUND_RESPONSES+=("$LAST_RESPONSE")
        if [ "$MAKE_SYMLINKS" -eq 1 ]; then
            create_symlink "$dev" "$LAST_RESPONSE"
        fi
        if [ "$LIST_ALL" -eq 0 ]; then
            break
        fi
    fi
done

if [ ${#FOUND_PORTS[@]} -eq 0 ]; then
    echo "Kein Arduino gefunden (keine passende Antwort auf '$IDENTIFY_CMD')." >&2
    exit 1
fi

if [ "$LIST_ALL" -eq 1 ]; then
    for i in "${!FOUND_PORTS[@]}"; do
        printf '%s\t%s\n' "${FOUND_PORTS[$i]}" "${FOUND_RESPONSES[$i]}"
    done
else
    printf '%s\t%s\n' "${FOUND_PORTS[0]}" "${FOUND_RESPONSES[0]}"
fi
