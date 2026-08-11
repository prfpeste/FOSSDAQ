#!/bin/bash
#
# install.sh
#
# Installiert Node-RED (offizieller Installer, falls noch nicht vorhanden),
# kopiert find_arduino.sh, setup-hotspot.sh, startup-sequence.sh/.service,
# 99-arduino.rules und find-arduino@.service an die richtigen Systemorte
# und aktiviert alles. Einmalig ausführen mit:
#
#   sudo ./install.sh
#
# WICHTIG: Muss im selben Verzeichnis liegen wie die o.g. Dateien
# (das Skript ermittelt seinen eigenen Ordner automatisch, ihr müsst
# also NICHT vorher irgendwohin "cd"en).
#
# Node-RED-Installation überspringen (z.B. weil schon vorhanden/eigenes
# Setup): SKIP_NODERED=1 sudo -E ./install.sh
#
# Hotspot-Pakete (hostapd/dnsmasq/nginx/iptables-persistent) NICHT
# installieren (z.B. weil schon vorhanden): SKIP_HOTSPOT_INSTALL=1 sudo -E ./install.sh
#
# Node-RED-Paletten (npm-Pakete), die automatisch installiert werden:
# Standard ist "@flowfuse/node-red-dashboard node-red-node-serialport"
# (Dashboard 2.0 - das alte "node-red-dashboard" ist deprecated).
# Eigene Liste (leerzeichengetrennt) angeben, z.B.:
#   NODERED_PALETTES="@flowfuse/node-red-dashboard node-red-contrib-modbus" sudo -E ./install.sh
# Keine Paletten installieren: NODERED_PALETTES="" sudo -E ./install.sh
#
# Webseiten-Pakete (python3-venv/python3-pip) NICHT installieren (z.B. weil
# schon vorhanden): SKIP_DASHBOARD_INSTALL=1 sudo -E ./install.sh
#
# Systembenutzer, unter dem die Webseite (lan-dashboard) läuft. Standard "pi"
# passend zu lan-dashboard.service/README. Eigenen Benutzer verwenden, z.B.:
#   DASHBOARD_USER=web sudo -E ./install.sh
#
# Admin-Passwort der Webseite nicht-interaktiv setzen (z.B. für automatisierte
# Installationen), sonst wird es abgefragt: DASHBOARD_ADMIN_PASSWORD="..." sudo -E ./install.sh

set -euo pipefail

SKIP_NODERED="${SKIP_NODERED:-0}"
SKIP_HOTSPOT_INSTALL="${SKIP_HOTSPOT_INSTALL:-0}"   # z.B. wenn hostapd/dnsmasq/nginx schon manuell eingerichtet sind
SKIP_DASHBOARD_INSTALL="${SKIP_DASHBOARD_INSTALL:-0}"   # z.B. wenn python3-venv/python3-pip schon vorhanden sind
NODERED_USER="${NODERED_USER:-nodered}"   # Systembenutzer, unter dem Node-RED läuft (NICHT root)
DASHBOARD_USER="${DASHBOARD_USER:-pi}"    # Systembenutzer, unter dem die Webseite (lan-dashboard) läuft
DASHBOARD_DIR="/home/$DASHBOARD_USER/lan-dashboard"
# Leerzeichengetrennte Liste an npm-Paketen, die in ~/.node-red des
# Node-RED-Benutzers installiert werden (erscheinen danach in der Palette).
# node-red-dashboard (Dashboard 1.0) ist seit Juni 2024 offiziell deprecated
# (keine Weiterentwicklung mehr) - @flowfuse/node-red-dashboard (Dashboard
# 2.0) ist der aktiv gepflegte Nachfolger, daher als Default gesetzt.
# Leer lassen (NODERED_PALETTES=""), um keine Paletten zu installieren.
NODERED_PALETTES="${NODERED_PALETTES:-@flowfuse/node-red-dashboard node-red-node-serialport}"

if [ "$EUID" -ne 0 ]; then
    echo "Bitte mit sudo ausführen: sudo $0"
    exit 1
fi

# Verzeichnis, in dem dieses Skript (und die anderen Dateien) liegen
SRC_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
echo ">>> Quellverzeichnis: $SRC_DIR"
cd "$SRC_DIR"

require_file() {
    if [ ! -f "$1" ]; then
        echo "FEHLER: $1 nicht gefunden in $SRC_DIR - Abbruch."
        exit 1
    fi
}

for f in find_arduino.sh setup-hotspot.sh startup-sequence.sh startup-sequence.service 99-arduino.rules find-arduino_.service; do
    require_file "$f"
done

for f in lan-dashboard/app.py lan-dashboard/requirements.txt lan-dashboard/lan-dashboard.service lan-dashboard/templates/index.html; do
    require_file "$f"
done

if [ "$SKIP_NODERED" -eq 1 ]; then
    echo ">>> SKIP_NODERED=1 gesetzt - überspringe Node-RED-Installation."
elif command -v node-red >/dev/null 2>&1; then
    echo ">>> Node-RED ist bereits installiert - überspringe Installation."
else
    echo ">>> Installiere Node.js + Node-RED (offizieller Installer) ..."
    # Offizieller Installer von nodered.org. --confirm-install überspringt die
    # interaktive Ja/Nein-Abfrage, --confirm-root erlaubt die Ausführung als
    # root (dieses Skript läuft ja bereits per sudo). Node-RED läuft SPÄTER
    # trotzdem nicht als root - siehe Benutzer-Anlage weiter unten.
    bash <(curl -sL https://raw.githubusercontent.com/node-red/linux-installers/master/deb/update-nodejs-and-nodered) --confirm-install --confirm-root
fi

echo ">>> Prüfe/lege Systembenutzer '$NODERED_USER' für Node-RED an ..."
if id "$NODERED_USER" >/dev/null 2>&1; then
    echo ">>> Benutzer '$NODERED_USER' existiert bereits."
else
    # --system: Systembenutzer (keine reguläre Login-Person, keine Passwortabfrage)
    # --create-home: legt Home-Verzeichnis an, in dem Node-RED sein
    #                Userverzeichnis (~/.node-red mit flows.json, Nodes, etc.) ablegt
    # --shell nologin: kein interaktiver Login möglich
    # --groups dialout: falls Node-RED-Flows (Serial-Nodes) direkt auf
    #                   /dev/ttyACM*/ttyUSB* zugreifen sollen
    useradd --system --create-home --home-dir "/home/$NODERED_USER" \
        --shell /usr/sbin/nologin --groups dialout "$NODERED_USER"
    echo ">>> Benutzer '$NODERED_USER' angelegt (Home: /home/$NODERED_USER, Gruppe dialout)."
fi

# Log-Verzeichnis gehört dem Node-RED-Benutzer, falls er (z.B. bei manuellen
# Tests außerhalb des Startskripts) selbst hineinschreiben will/muss.
mkdir -p /var/log/node-red
chown "$NODERED_USER":"$NODERED_USER" /var/log/node-red

NODERED_HOME="/home/$NODERED_USER"
NODERED_DIR="$NODERED_HOME/.node-red"

if [ -n "$NODERED_PALETTES" ]; then
    echo ">>> Installiere Node-RED-Paletten: $NODERED_PALETTES"
    mkdir -p "$NODERED_DIR"
    chown "$NODERED_USER":"$NODERED_USER" "$NODERED_DIR"

    # ~/.node-red braucht eine package.json, damit "npm install" die Pakete
    # als Abhängigkeiten dort einträgt (so erkennt Node-RED sie beim Start
    # als Paletten). Existiert noch keine (z.B. weil Node-RED hier noch nie
    # gestartet wurde), legen wir eine minimale an.
    #
    # WICHTIG: NICHT "npm init -y" verwenden - npm leitet den Default-Namen
    # vom Verzeichnisnamen ab, und ".node-red" beginnt mit einem Punkt, was
    # kein gültiger npm-Paketname ist ("npm error invalid name"). Die
    # package.json wird dann NICHT angelegt und "npm install" schlägt
    # danach fehl. Stattdessen die Datei direkt mit einem gültigen Namen
    # schreiben.
    if [ ! -f "$NODERED_DIR/package.json" ]; then
        runuser -u "$NODERED_USER" -- bash -c "cat > '$NODERED_DIR/package.json' <<'PKGJSON'
{
  \"name\": \"node-red-user-dir\",
  \"version\": \"1.0.0\",
  \"description\": \"Node-RED user directory\",
  \"private\": true
}
PKGJSON"
    fi

    # Als NODERED_USER (nicht root) installieren, damit Dateirechte in
    # ~/.node-red stimmen - genau wie Node-RED selbst später auch als
    # dieser Benutzer läuft (siehe startup-sequence.sh).
    if ! runuser -u "$NODERED_USER" -- bash -c "cd '$NODERED_DIR' && npm install --no-audit --no-fund $NODERED_PALETTES"; then
        echo "WARNUNG: Installation mindestens einer Palette ist fehlgeschlagen - bitte Ausgabe oben prüfen."
        echo "Node-RED startet trotzdem, ggf. fehlt dann nur der/die betroffene(n) Node(s) in der Palette."
    fi
else
    echo ">>> NODERED_PALETTES ist leer - überspringe Paletten-Installation."
fi

echo ">>> Kopiere Skripte nach /usr/local/bin ..."
cp find_arduino.sh setup-hotspot.sh startup-sequence.sh /usr/local/bin/
chmod +x /usr/local/bin/find_arduino.sh /usr/local/bin/setup-hotspot.sh /usr/local/bin/startup-sequence.sh

# ==========================================================================
# Webseite (lan-dashboard) einrichten
#
# Wird NICHT per "systemctl enable" eigenständig gestartet - sonst würde
# systemd sie parallel/unkoordiniert zum Hotspot hochfahren. Stattdessen
# startet startup-sequence.sh sie gezielt per "systemctl start" und wartet,
# bis sie antwortet, BEVOR der Hotspot online geht (siehe startup-sequence.sh).
# ==========================================================================
echo ">>> Richte Webseite (lan-dashboard) ein ..."

if [ "$SKIP_DASHBOARD_INSTALL" -eq 1 ]; then
    echo ">>> SKIP_DASHBOARD_INSTALL=1 gesetzt - überspringe Paketinstallation (python3-venv/python3-pip)."
else
    echo ">>> Installiere Python-Abhängigkeiten (python3-venv, python3-pip) ..."
    apt update
    apt install -y python3-venv python3-pip
fi

echo ">>> Prüfe/lege Systembenutzer '$DASHBOARD_USER' für die Webseite an ..."
if id "$DASHBOARD_USER" >/dev/null 2>&1; then
    echo ">>> Benutzer '$DASHBOARD_USER' existiert bereits."
else
    # Regulärer Benutzer mit Home-Verzeichnis (kein --system), da "pi" auf
    # einem echten Raspberry Pi normalerweise ohnehin schon existiert - dieser
    # Zweig greift nur auf Systemen, auf denen er fehlt (z.B. reines Ubuntu).
    useradd --create-home --shell /bin/bash "$DASHBOARD_USER"
    echo ">>> Benutzer '$DASHBOARD_USER' angelegt (Home: /home/$DASHBOARD_USER)."
fi

echo ">>> Kopiere Webseiten-Dateien nach $DASHBOARD_DIR ..."
mkdir -p "$DASHBOARD_DIR"
for item in app.py requirements.txt README.md templates static; do
    cp -r "lan-dashboard/$item" "$DASHBOARD_DIR/"
done

# Laufzeitdaten (Schaltflächen, Design, Admin-Passwort-Hash) nur kopieren,
# falls dort noch keine vorhanden sind - so gehen bei einem erneuten Lauf von
# install.sh keine bereits über die Weboberfläche vorgenommenen Änderungen
# verloren.
for datafile in buttons.json settings.json admin_config.json; do
    if [ -f "$DASHBOARD_DIR/$datafile" ]; then
        echo ">>> $datafile existiert bereits in $DASHBOARD_DIR - behalte vorhandene Datei."
    elif [ -f "lan-dashboard/$datafile" ]; then
        cp "lan-dashboard/$datafile" "$DASHBOARD_DIR/"
    fi
done
mkdir -p "$DASHBOARD_DIR/static/uploads"

chown -R "$DASHBOARD_USER":"$DASHBOARD_USER" "$DASHBOARD_DIR"

echo ">>> Richte Python-Umgebung (venv) für die Webseite ein ..."
if [ ! -x "$DASHBOARD_DIR/venv/bin/python" ]; then
    runuser -u "$DASHBOARD_USER" -- bash -c "cd '$DASHBOARD_DIR' && python3 -m venv venv"
fi
runuser -u "$DASHBOARD_USER" -- bash -c "cd '$DASHBOARD_DIR' && venv/bin/pip install --no-input --quiet --upgrade pip && venv/bin/pip install --no-input --quiet -r requirements.txt"

echo ">>> Prüfe/erzeuge .env (Admin-Passwort & Secret Key) für die Webseite ..."
if [ -f "$DASHBOARD_DIR/.env" ]; then
    echo ">>> $DASHBOARD_DIR/.env existiert bereits - lasse sie unverändert."
else
    if [ -n "${DASHBOARD_ADMIN_PASSWORD:-}" ]; then
        DASHBOARD_PASSWORD="$DASHBOARD_ADMIN_PASSWORD"
    else
        while true; do
            read -rsp "Admin-Passwort für die Webseite eingeben (mind. 4 Zeichen): " DASHBOARD_PASSWORD
            echo
            read -rsp "Admin-Passwort erneut eingeben: " DASHBOARD_PASSWORD_CONFIRM
            echo
            if [ "$DASHBOARD_PASSWORD" != "$DASHBOARD_PASSWORD_CONFIRM" ]; then
                echo ">>> Passwörter stimmen nicht überein - bitte erneut versuchen."
                continue
            fi
            if [ "${#DASHBOARD_PASSWORD}" -lt 4 ]; then
                echo ">>> Passwort muss mindestens 4 Zeichen lang sein - bitte erneut versuchen."
                continue
            fi
            break
        done
    fi

    DASHBOARD_SECRET_KEY="$("$DASHBOARD_DIR/venv/bin/python" -c 'import secrets; print(secrets.token_hex(32))')"

    cat > "$DASHBOARD_DIR/.env" <<EOF
ADMIN_PASSWORD=$DASHBOARD_PASSWORD
SECRET_KEY=$DASHBOARD_SECRET_KEY
EOF
    chown "$DASHBOARD_USER":"$DASHBOARD_USER" "$DASHBOARD_DIR/.env"
    chmod 600 "$DASHBOARD_DIR/.env"
fi

echo ">>> Installiere Systemd-Unit für die Webseite ..."
# lan-dashboard.service ist fest auf Benutzer/Pfad "pi" ausgelegt - beim
# Installieren auf $DASHBOARD_USER/$DASHBOARD_DIR anpassen (Quelldatei bleibt
# dabei unverändert, es wird nur die installierte Kopie angepasst).
sed -e "s#/home/pi/lan-dashboard#$DASHBOARD_DIR#g" \
    -e "s/^User=pi$/User=$DASHBOARD_USER/" \
    lan-dashboard/lan-dashboard.service > /etc/systemd/system/lan-dashboard.service

echo ">>> Konfiguriere Hotspot (WLAN-Name & Passwort) ..."
while true; do
    read -rp "WLAN-Name (SSID) eingeben: " HOTSPOT_SSID
    read -rp "SSID '$HOTSPOT_SSID' verwenden? [y/n] " HOTSPOT_SSID_CONFIRM
    case "$HOTSPOT_SSID_CONFIRM" in
        [Yy]*) break ;;
        *) echo ">>> Ok, bitte SSID erneut eingeben." ;;
    esac
done

while true; do
    read -rsp "WLAN-Passwort eingeben (mind. 8 Zeichen): " HOTSPOT_PASSWORD
    echo
    read -rsp "WLAN-Passwort erneut eingeben: " HOTSPOT_PASSWORD_CONFIRM
    echo
    if [ "$HOTSPOT_PASSWORD" != "$HOTSPOT_PASSWORD_CONFIRM" ]; then
        echo ">>> Passwörter stimmen nicht überein - bitte erneut versuchen."
        continue
    fi
    if [ "${#HOTSPOT_PASSWORD}" -lt 8 ]; then
        echo ">>> Passwort muss mindestens 8 Zeichen lang sein - bitte erneut versuchen."
        continue
    fi
    break
done

echo ">>> Schreibe Hotspot-Konfiguration nach /etc/default/hotspot ..."
cat > /etc/default/hotspot <<EOF
# Wird von setup-hotspot.sh eingelesen (überschreibt SSID/PASSWORD dort).
SSID="$HOTSPOT_SSID"
PASSWORD="$HOTSPOT_PASSWORD"
EOF
chmod 600 /etc/default/hotspot

if [ "$SKIP_HOTSPOT_INSTALL" -eq 1 ]; then
    echo ">>> SKIP_HOTSPOT_INSTALL=1 gesetzt - überspringe Hotspot-Paketinstallation (hostapd/dnsmasq/nginx)."
else
    echo ">>> Installiere Hotspot-Abhängigkeiten (hostapd, dnsmasq, nginx, iptables-persistent) ..."
    # WICHTIG: Ohne diesen Schritt fehlt beim Boot der Befehl 'hostapd'
    # ("Kommando nicht gefunden"), da startup-sequence.sh -> setup-hotspot.sh
    # start davon ausgeht, dass die Pakete bereits vorhanden sind.
    /usr/local/bin/setup-hotspot.sh install
fi

echo ">>> Schreibe Konfiguration (Node-RED-Benutzer) nach /etc/default/startup-sequence ..."
cat > /etc/default/startup-sequence <<EOF
# Wird von startup-sequence.sh per systemd EnvironmentFile eingelesen.
NODERED_USER=$NODERED_USER
EOF

echo ">>> Kopiere Systemd-Unit für die Boot-Startsequenz ..."
cp startup-sequence.service /etc/systemd/system/

echo ">>> Kopiere udev-Regel und Hotplug-Service ..."
cp 99-arduino.rules /etc/udev/rules.d/
cp find-arduino_.service /etc/systemd/system/find-arduino@.service

echo ">>> Lade udev-Regeln neu ..."
udevadm control --reload
udevadm trigger

echo ">>> Lade systemd neu und aktiviere startup-sequence.service ..."
systemctl daemon-reload
systemctl enable startup-sequence.service
# lan-dashboard.service bewusst NICHT per "systemctl enable" aktivieren:
# startup-sequence.sh startet sie gezielt (vor dem Hotspot), damit die
# Reihenfolge beim Boot garantiert stimmt (siehe Kommentar dort).

if [ -d /root/.node-red ] && [ ! -d "/home/$NODERED_USER/.node-red/node_modules" ]; then
    echo ""
    echo "HINWEIS: Unter /root/.node-red liegen offenbar noch Daten aus einem"
    echo "früheren Lauf (als root). Node-RED läuft jetzt als '$NODERED_USER' und"
    echo "sucht sein Userverzeichnis unter /home/$NODERED_USER/.node-red - alte"
    echo "Flows werden NICHT automatisch übernommen. Zum manuellen Übertragen z.B.:"
    echo "  sudo cp -r /root/.node-red/. /home/$NODERED_USER/.node-red/"
    echo "  sudo chown -R $NODERED_USER:$NODERED_USER /home/$NODERED_USER/.node-red"
fi

echo ""
echo "=========================================="
echo " Installation abgeschlossen."
echo " Testen ohne Neustart: sudo systemctl start startup-sequence.service"
echo " Status prüfen:        systemctl status startup-sequence.service"
echo " Logs ansehen:         journalctl -u startup-sequence.service -e"
echo " Webseite (lan-dashboard): http://<Pi-IP>:5000 - Status: systemctl status lan-dashboard.service"
echo "=========================================="
