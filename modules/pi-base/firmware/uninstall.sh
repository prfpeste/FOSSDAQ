#!/bin/bash
#
# uninstall.sh
#
# Macht alles rückgängig, was install.sh eingerichtet hat: stoppt und
# deaktiviert alle Dienste, entfernt die Hotspot-Netzwerkeinstellungen
# (hostapd/dnsmasq/nginx/iptables), löscht alle kopierten Skripte,
# systemd-Units, udev-Regeln, sudo-Rechte und - sofern nicht anders
# angegeben - auch die Webseiten-/Node-RED-Verzeichnisse und die dafür
# angelegten Systembenutzer.
#
# Einmalig ausführen mit:
#   sudo ./uninstall.sh
#
# Es wird NICHT nachgefragt - das Skript läuft vollautomatisch durch.
#
# Optionen (per Umgebungsvariable, gleiche Namen wie in install.sh):
#   DASHBOARD_USER=web sudo -E ./uninstall.sh   -> falls beim Install ein
#                                                   anderer Benutzer als "pi"
#                                                   verwendet wurde
#   NODERED_USER=xyz sudo -E ./uninstall.sh     -> falls beim Install ein
#                                                   anderer Node-RED-Benutzer
#                                                   verwendet wurde
#   KEEP_USERS=1 sudo -E ./uninstall.sh         -> Systembenutzer (pi/nodered)
#                                                   NICHT löschen (nur deren
#                                                   Hotspot-/Node-RED-Daten)
#   KEEP_PACKAGES=1 sudo -E ./uninstall.sh      -> hostapd/dnsmasq/nginx/
#                                                   Node-RED/Node.js NICHT
#                                                   deinstallieren, nur die
#                                                   Konfiguration entfernen
# ============================================================

set -uo pipefail   # bewusst OHNE "-e": eine einzelne fehlende Datei/ein
                    # bereits inaktiver Dienst soll die Deinstallation nicht
                    # abbrechen - es soll so viel wie möglich aufgeräumt werden

if [ "$EUID" -ne 0 ]; then
    echo "Bitte mit sudo ausführen: sudo $0"
    exit 1
fi

DASHBOARD_USER="${DASHBOARD_USER:-pi}"
NODERED_USER="${NODERED_USER:-nodered}"
KEEP_USERS="${KEEP_USERS:-0}"
KEEP_PACKAGES="${KEEP_PACKAGES:-0}"
DASHBOARD_DIR="/home/$DASHBOARD_USER/lan-dashboard"
WLAN_IFACE="${WLAN_IFACE:-wlan0}"
HOTSPOT_IP="${HOTSPOT_IP:-192.168.50.1}"

echo "=========================================="
echo " Deinstallation wird gestartet ..."
echo " DASHBOARD_USER=$DASHBOARD_USER  NODERED_USER=$NODERED_USER"
echo "=========================================="

# ------------------------------------------------------------------
# 1) Hotspot stoppen und Netzwerkzustand zurücksetzen
# ------------------------------------------------------------------
echo ">>> Stoppe laufenden Hotspot (falls aktiv) ..."
if [ -x /usr/local/bin/setup-hotspot.sh ]; then
    /usr/local/bin/setup-hotspot.sh stop 2>/dev/null || true
elif [ -x "$(dirname "$(readlink -f "$0")")/setup-hotspot.sh" ]; then
    "$(dirname "$(readlink -f "$0")")/setup-hotspot.sh" stop 2>/dev/null || true
fi

echo ">>> Beende ggf. übrig gebliebene hostapd-/dnsmasq-Prozesse ..."
pkill -f "hostapd.*hostapd-hotspot.conf" 2>/dev/null || true
pkill -f "dnsmasq.*dnsmasq-hotspot.conf" 2>/dev/null || true

echo ">>> Entferne iptables-Regeln ..."
iptables -t nat -D PREROUTING -i "$WLAN_IFACE" -p tcp --dport 80 -j DNAT --to-destination "$HOTSPOT_IP:80" 2>/dev/null || true
iptables -D FORWARD -i "$WLAN_IFACE" -p tcp --dport 443 -j REJECT --reject-with tcp-reset 2>/dev/null || true
iptables -D FORWARD -i "$WLAN_IFACE" -p tcp --dport 853 -j REJECT --reject-with tcp-reset 2>/dev/null || true
netfilter-persistent save 2>/dev/null || true

echo ">>> Gebe $WLAN_IFACE wieder an NetworkManager zurück ..."
nmcli device set "$WLAN_IFACE" managed yes 2>/dev/null || true
nmcli connection delete hotspot-portal 2>/dev/null || true
ip addr flush dev "$WLAN_IFACE" 2>/dev/null || true

# ------------------------------------------------------------------
# 2) systemd-Dienste stoppen, deaktivieren und Unit-Dateien entfernen
# ------------------------------------------------------------------
echo ">>> Stoppe und deaktiviere systemd-Dienste ..."
for svc in startup-sequence.service lan-dashboard.service find-arduino@.service; do
    systemctl stop "$svc" 2>/dev/null || true
    systemctl disable "$svc" 2>/dev/null || true
done
systemctl disable --now hostapd 2>/dev/null || true
systemctl disable --now dnsmasq 2>/dev/null || true

echo ">>> Entferne systemd-Unit-Dateien ..."
rm -f /etc/systemd/system/startup-sequence.service
rm -f /etc/systemd/system/lan-dashboard.service
rm -f /etc/systemd/system/find-arduino@.service
systemctl daemon-reload
systemctl reset-failed 2>/dev/null || true

# ------------------------------------------------------------------
# 3) udev-Regeln entfernen
# ------------------------------------------------------------------
echo ">>> Entferne udev-Regel ..."
rm -f /etc/udev/rules.d/99-arduino.rules
udevadm control --reload 2>/dev/null || true
udevadm trigger 2>/dev/null || true

# ------------------------------------------------------------------
# 4) nginx-Konfiguration entfernen
# ------------------------------------------------------------------
echo ">>> Entferne nginx-Konfiguration ..."
rm -f /etc/nginx/sites-enabled/hotspot-portal
rm -f /etc/nginx/sites-available/hotspot-portal
# Ubuntu-Standardseite wieder aktivieren, falls sie noch existiert, damit
# nginx nach der Deinstallation nicht ganz ohne aktivierte Seite dasteht
if [ -f /etc/nginx/sites-available/default ] && [ ! -e /etc/nginx/sites-enabled/default ]; then
    ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default
fi
nginx -t 2>/dev/null && systemctl restart nginx 2>/dev/null || systemctl stop nginx 2>/dev/null || true

# ------------------------------------------------------------------
# 5) Eigene Domains aus /etc/hosts entfernen
# ------------------------------------------------------------------
echo ">>> Entferne dashboard.hotspot/nodered.hotspot aus /etc/hosts ..."
sed -i -E '/\s(dashboard\.hotspot|nodered\.hotspot)\s*$/d' /etc/hosts

# ------------------------------------------------------------------
# 6) sudo-Rechte entfernen
# ------------------------------------------------------------------
echo ">>> Entferne sudoers-Eintrag ..."
rm -f /etc/sudoers.d/lan-dashboard

# ------------------------------------------------------------------
# 7) Kopierte Skripte und Laufzeit-/Konfigurationsdateien entfernen
# ------------------------------------------------------------------
echo ">>> Entferne Skripte aus /usr/local/bin ..."
rm -f /usr/local/bin/find_arduino.sh
rm -f /usr/local/bin/setup-hotspot.sh
rm -f /usr/local/bin/startup-sequence.sh

echo ">>> Entferne /etc/default-Konfigurationsdateien ..."
rm -f /etc/default/startup-sequence
rm -f /etc/default/hotspot

echo ">>> Entferne verwaiste Laufzeitdateien in /run ..."
rm -f /run/dnsmasq-hotspot.conf /run/dnsmasq-hotspot.pid
rm -f /run/hostapd-hotspot.conf /run/hostapd-hotspot.pid

# ------------------------------------------------------------------
# 8) Webseite (lan-dashboard) entfernen
# ------------------------------------------------------------------
echo ">>> Entferne Webseiten-Verzeichnis $DASHBOARD_DIR ..."
rm -rf "$DASHBOARD_DIR"

# ------------------------------------------------------------------
# 9) Node-RED-Daten entfernen
# ------------------------------------------------------------------
echo ">>> Entferne Node-RED-Benutzerverzeichnis /home/$NODERED_USER/.node-red ..."
rm -rf "/home/$NODERED_USER/.node-red"
rm -rf "/var/log/node-red"

# ------------------------------------------------------------------
# 10) Systembenutzer entfernen (samt Home-Verzeichnis), außer KEEP_USERS=1
# ------------------------------------------------------------------
if [ "$KEEP_USERS" -eq 1 ]; then
    echo ">>> KEEP_USERS=1 gesetzt - Systembenutzer '$DASHBOARD_USER' und '$NODERED_USER' bleiben erhalten."
else
    echo ">>> Entferne Systembenutzer '$NODERED_USER' (falls vorhanden) ..."
    if id "$NODERED_USER" >/dev/null 2>&1; then
        userdel --remove "$NODERED_USER" 2>/dev/null || echo "WARNUNG: Benutzer '$NODERED_USER' konnte nicht vollständig entfernt werden (evtl. noch laufende Prozesse)."
    fi

    echo ">>> Entferne Systembenutzer '$DASHBOARD_USER' (falls vorhanden und kein regulärer Login-Benutzer, den du weiterverwenden willst) ..."
    if id "$DASHBOARD_USER" >/dev/null 2>&1; then
        userdel --remove "$DASHBOARD_USER" 2>/dev/null || echo "WARNUNG: Benutzer '$DASHBOARD_USER' konnte nicht vollständig entfernt werden (evtl. noch laufende Prozesse oder es ist dein eigener Login-Benutzer)."
    fi
fi

# ------------------------------------------------------------------
# 11) Optional: installierte Pakete entfernen
# ------------------------------------------------------------------
if [ "$KEEP_PACKAGES" -eq 1 ]; then
    echo ">>> KEEP_PACKAGES=1 gesetzt - Pakete (hostapd/dnsmasq/nginx/Node-RED/Node.js) bleiben installiert."
else
    echo ">>> Entferne Pakete hostapd, dnsmasq, nginx, iptables-persistent ..."
    apt purge -y hostapd dnsmasq nginx nginx-common iptables-persistent 2>/dev/null || true
    apt autoremove -y 2>/dev/null || true

    echo ">>> Entferne Node-RED und Node.js (global installiert) ..."
    npm uninstall -g --unsafe-perm node-red 2>/dev/null || true
fi

echo ""
echo "=========================================="
echo " Deinstallation abgeschlossen."
echo " WLAN-Interface $WLAN_IFACE läuft wieder unter NetworkManager."
echo " Ein Neustart des Systems wird empfohlen, um sicherzugehen,"
echo " dass keine alten Prozesse/Netzwerkzustände mehr aktiv sind."
echo "=========================================="
