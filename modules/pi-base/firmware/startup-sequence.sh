#!/bin/bash
#
# startup-sequence.sh
#
# Wird beim Booten per systemd (startup-sequence.service) als root
# ausgeführt. Reihenfolge:
#   1) Symlinks für ALLE bereits angeschlossenen Arduinos anlegen
#      (find_arduino.sh -a -s) - deckt Geräte ab, die schon beim
#      Boot stecken. Neu angesteckte Geräte übernimmt danach die
#      udev-Regel (99-arduino.rules -> find-arduino@.service).
#   2) Node-RED starten und warten, bis es antwortet.
#   3) Webseite (lan-dashboard.service) starten und warten, bis sie
#      antwortet. Läuft bewusst über "systemctl start" statt eigenem
#      "systemctl enable" (siehe install.sh), damit sie garantiert VOR
#      dem Hotspot steht statt unkoordiniert parallel dazu hochzufahren.
#   4) Hotspot starten (setup-hotspot.sh start), dessen Captive
#      Portal auf Node-RED verweist -> darum erst NACH Node-RED und
#      der Webseite.
#
# Installation siehe Kommentar am Ende der Datei / Chat-Anleitung.

set -uo pipefail

FIND_ARDUINO="/usr/local/bin/find_arduino.sh"
SETUP_HOTSPOT="/usr/local/bin/setup-hotspot.sh"

# Wird i.d.R. von /etc/default/startup-sequence (via systemd EnvironmentFile)
# gesetzt, siehe install.sh. Fallback "nodered" nur für manuelle Testläufe.
NODERED_USER="${NODERED_USER:-nodered}"

NODERED_PORT=1880
NODERED_WAIT_SEC=60          # max. Wartezeit auf Node-RED, bevor trotzdem weitergemacht wird

DASHBOARD_SERVICE="lan-dashboard.service"
DASHBOARD_PORT=5000
DASHBOARD_WAIT_SEC=30        # max. Wartezeit auf die Webseite, bevor trotzdem weitergemacht wird

log() {
    echo "[startup-sequence] $*"
}

# --------------------------------------------------------------------
# 1) Symlinks für alle bereits angeschlossenen Arduinos
# --------------------------------------------------------------------
log "Warte auf udev (Geräte-Erkennung abschließen) ..."
udevadm settle --timeout=10 || true

if [ -x "$FIND_ARDUINO" ]; then
    log "Suche bereits angeschlossene Arduinos und lege Symlinks an ..."
    "$FIND_ARDUINO" -a -s
else
    log "WARNUNG: $FIND_ARDUINO nicht gefunden/ausführbar - überspringe Symlink-Erstellung."
fi

# --------------------------------------------------------------------
# 2) Node-RED starten
# --------------------------------------------------------------------
start_nodered() {
    local nodered_bin
    nodered_bin="$(command -v node-red || true)"
    if [ -z "$nodered_bin" ]; then
        log "FEHLER: Befehl 'node-red' nicht gefunden (nicht im PATH von root/systemd)."
        return 1
    fi

    if ! id "$NODERED_USER" >/dev/null 2>&1; then
        log "FEHLER: Benutzer '$NODERED_USER' existiert nicht. install.sh (neu) ausführen, um ihn anzulegen."
        return 1
    fi

    log "Starte Node-RED im Hintergrund als Benutzer '$NODERED_USER' (Log: /var/log/node-red/node-red.log) ..."
    mkdir -p /var/log/node-red
    chown "$NODERED_USER":"$NODERED_USER" /var/log/node-red

    # Node-RED läuft bewusst NICHT als root, sondern als eigener
    # Systembenutzer ($NODERED_USER, siehe install.sh). runuser wechselt
    # UID/GID und setzt dabei automatisch $HOME auf dessen Home-Verzeichnis,
    # wodurch Node-RED sein Userverzeichnis (~/.node-red) korrekt findet
    # ("could not find user directory" tritt damit nicht mehr auf).
    # Absoluter Pfad ($nodered_bin) statt "node-red", da runuser ohne
    # --login ggf. ein anderes PATH verwendet.
    nohup runuser -u "$NODERED_USER" -- "$nodered_bin" \
        >> /var/log/node-red/node-red.log 2>&1 < /dev/null &
    disown
}

start_nodered

log "Warte auf Node-RED auf Port $NODERED_PORT (max. ${NODERED_WAIT_SEC}s) ..."
waited=0
while ! curl -s -o /dev/null "http://127.0.0.1:${NODERED_PORT}/"; do
    sleep 1
    waited=$((waited + 1))
    if [ "$waited" -ge "$NODERED_WAIT_SEC" ]; then
        log "WARNUNG: Node-RED antwortet nach ${NODERED_WAIT_SEC}s immer noch nicht - fahre trotzdem fort."
        break
    fi
done
[ "$waited" -lt "$NODERED_WAIT_SEC" ] && log "Node-RED ist erreichbar."

# --------------------------------------------------------------------
# 3) Webseite (lan-dashboard) starten
# --------------------------------------------------------------------
log "Starte Webseite ($DASHBOARD_SERVICE) ..."
if systemctl list-unit-files "$DASHBOARD_SERVICE" >/dev/null 2>&1 && \
   systemctl list-unit-files "$DASHBOARD_SERVICE" | grep -q "$DASHBOARD_SERVICE"; then
    if ! systemctl start "$DASHBOARD_SERVICE"; then
        log "WARNUNG: $DASHBOARD_SERVICE konnte nicht gestartet werden - fahre trotzdem fort (siehe: journalctl -u $DASHBOARD_SERVICE)."
    fi

    log "Warte auf Webseite auf Port $DASHBOARD_PORT (max. ${DASHBOARD_WAIT_SEC}s) ..."
    waited=0
    while ! curl -s -o /dev/null "http://127.0.0.1:${DASHBOARD_PORT}/"; do
        sleep 1
        waited=$((waited + 1))
        if [ "$waited" -ge "$DASHBOARD_WAIT_SEC" ]; then
            log "WARNUNG: Webseite antwortet nach ${DASHBOARD_WAIT_SEC}s immer noch nicht - fahre trotzdem fort."
            break
        fi
    done
    [ "$waited" -lt "$DASHBOARD_WAIT_SEC" ] && log "Webseite ist erreichbar."
else
    log "WARNUNG: $DASHBOARD_SERVICE nicht installiert (install.sh (neu) ausführen) - überspringe Webseiten-Start."
fi

# --------------------------------------------------------------------
# 4) Hotspot starten
# --------------------------------------------------------------------
if [ -x "$SETUP_HOTSPOT" ]; then
    log "Starte Hotspot ..."
    "$SETUP_HOTSPOT" start
else
    log "FEHLER: $SETUP_HOTSPOT nicht gefunden/ausführbar - Hotspot wurde NICHT gestartet."
    exit 1
fi

log "Startsequenz abgeschlossen."
