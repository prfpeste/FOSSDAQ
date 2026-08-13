#!/bin/bash
set -e

# ============================================================
# Ubuntu Hotspot mit automatischem Captive Portal (ohne Login)
# ============================================================
# Baut ein WLAN auf. Wer sich verbindet, bekommt automatisch
# die definierte Webseite angezeigt (wie im Café/Flughafen-WLAN).
# Es gibt keine "Freischaltung" - die Seite öffnet sich einfach.
#
# Erkennung erfolgt über ZWEI parallele Mechanismen:
#  1) DHCP Option 114 / RFC 8910 + Captive-Portal-API (RFC 8908)
#     -> zuverlässig auf Android 11+ und iOS 14+/macOS, ohne
#        DNS- oder Port-Hijacking.
#  2) DNS-Wildcard + HTTP(80)-Redirect + Blockieren von 443/853
#     -> Fallback für Windows und Geräte ohne RFC-8910-Support.
#
# WICHTIG - Warum hostapd statt NetworkManager-AP-Modus:
# Auf modernem Ubuntu spiegelt netplan jede per "nmcli" angelegte
# NetworkManager-Verbindung automatisch nach /etc/netplan/*.yaml.
# Das netplan-Schema kennt für eine Wifi-AP-Verbindung mit fester
# Adresse aber keinen echten "ipv4.method=manual"-Zustand - beim
# Rückübersetzen wird die Verbindung immer wieder auf
# "ipv4.method=shared" gesetzt (NetworkManagers eigener interner
# DHCP/DNS-Mechanismus fürs Tethering). Das kollidiert mit unserem
# eigenen dnsmasq (doppelter DHCP-Server, doppeltes DNS, instabile
# Aktivierung, siehe "ip-config-unavailable"-Fehler). Jeder Versuch,
# das nur über nmcli zu reparieren, wird beim nächsten netplan-Sync
# wieder zurückgesetzt. Deshalb: wlan0 komplett aus der
# NetworkManager-Verwaltung nehmen und den AP direkt mit hostapd
# betreiben - der klassische, robuste Ansatz für genau diesen Zweck.
#
# Verwendung:
#   sudo ./setup-hotspot.sh install   -> einmalig Pakete installieren
#   sudo ./setup-hotspot.sh start     -> Hotspot starten
#   sudo ./setup-hotspot.sh stop      -> Hotspot stoppen
# ============================================================

# ---- KONFIGURATION: hier anpassen ----
SSID="Hotspot"
PASSWORD="Password"             # mind. 8 Zeichen
WLAN_IFACE="wlan0"              # mit `ip a` prüfen, ggf. anpassen
WLAN_CHANNEL="6"                # 2.4GHz-Kanal (1, 6 oder 11 empfohlen)
HOTSPOT_IP="192.168.50.1"
DHCP_RANGE_START="192.168.50.10"
DHCP_RANGE_END="192.168.50.100"
COUNTRY_CODE="DE"               # ISO-3166-1 alpha2 Ländercode für die WLAN-Regulatory-Domain.
                                 # Ohne gesetztes Land bleibt der Kernel in der "world"-Domain,
                                 # die auf vielen Chipsätzen aktives Senden (Beaconing) auf
                                 # 2.4GHz-Kanälen verweigert -> hostapd bricht dann mit
                                 # "nl80211: Failed to set channel" / "could not set channel
                                 # for kernel driver" ab, obwohl die Config sonst korrekt ist.
DASHBOARD_DOMAIN="dashboard.hotspot"            # Domain fürs lan-dashboard (Port 5000 intern)
NODERED_DOMAIN="nodered.hotspot"                # Domain für Node-RED (Port 1880 intern)
DASHBOARD_PORT="5000"
NODERED_PORT="1880"
PORTAL_TARGET="http://$DASHBOARD_DOMAIN"        # Ziel-Webseite, die beim Verbinden geöffnet wird
CAPTIVE_API_PATH="/captive-portal-api"          # Pfad, unter dem die RFC8908-JSON-API liegt
# ---------------------------------------

# SSID/Passwort werden NICHT mehr bei der Installation abgefragt, sondern
# starten mit den Standardwerten oben ("Hotspot" / "Password") und können
# anschließend über die Weboberfläche (Admin-Modus -> WLAN-Einstellungen)
# geändert werden. Die Weboberfläche schreibt dazu hotspot_config.json im
# lan-dashboard-Verzeichnis des konfigurierten Dashboard-Benutzers - das wird
# hier eingelesen und überschreibt die Standardwerte oben. Existiert die
# Datei nicht (z.B. beim direkten Testen dieses Skripts ohne install.sh),
# gelten einfach die Standardwerte oben weiter.
DASHBOARD_USER="${DASHBOARD_USER:-pi}"
HOTSPOT_CONFIG_JSON="/home/$DASHBOARD_USER/lan-dashboard/hotspot_config.json"
if [ -f "$HOTSPOT_CONFIG_JSON" ] && command -v python3 >/dev/null 2>&1; then
    eval "$(python3 -c '
import json, shlex, sys
try:
    with open(sys.argv[1], "r", encoding="utf-8") as f:
        data = json.load(f)
    if data.get("ssid"):
        print("SSID=" + shlex.quote(str(data["ssid"])))
    if data.get("password"):
        print("PASSWORD=" + shlex.quote(str(data["password"])))
except Exception:
    pass
' "$HOTSPOT_CONFIG_JSON")"
fi

# /etc/default/hotspot bleibt zusätzlich als manuelle Override-Möglichkeit
# bestehen (z.B. für Systeme ohne Weboberfläche) und hat Vorrang vor der JSON.
[ -f /etc/default/hotspot ] && source /etc/default/hotspot

# Erlaubt, das Land zusätzlich per env COUNTRY_CODE=XX zu überschreiben
# (z.B. für manuelle Tests), ohne /etc/default/hotspot anfassen zu müssen.
COUNTRY_CODE="${COUNTRY_CODE:-DE}"

CAPTIVE_API_URL="http://$DASHBOARD_DOMAIN$CAPTIVE_API_PATH"
DNSMASQ_CONF="/run/dnsmasq-hotspot.conf"
DNSMASQ_PID="/run/dnsmasq-hotspot.pid"
HOSTAPD_CONF="/run/hostapd-hotspot.conf"
HOSTAPD_PID="/run/hostapd-hotspot.pid"

require_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "Bitte mit sudo ausführen: sudo $0 $1"
        exit 1
    fi
}

install_packages() {
    require_root install
    echo ">>> Installiere benötigte Pakete..."
    apt update
    apt install -y hostapd dnsmasq nginx iptables-persistent

    # hostapd und dnsmasq sollen NICHT global als Dienst laufen (würden mit
    # NetworkManager/systemd-resolved kollidieren) - wir starten beide gezielt
    # nur für das Hotspot-Interface, siehe start_hotspot().
    systemctl disable --now hostapd 2>/dev/null || true
    systemctl disable --now dnsmasq 2>/dev/null || true

    # nginx: liefert die Portalseite (Reverse Proxy) sowie die
    # RFC8908-Captive-Portal-API (statisches JSON, immer "captive": true,
    # da es hier keine echte Freischaltung/Login gibt).
    #
    # HINWEIS: Bewusst NUR Port 80. HTTPS (443) wird per iptables aktiv per
    # TCP-Reset abgewiesen, damit Geräte ohne RFC8910-Support zügig auf den
    # unverschlüsselten Connectivity-Check ausweichen, statt an einem
    # Zertifikatsfehler eines Self-Signed-443-vHosts hängen zu bleiben.
    cat > /etc/nginx/sites-available/hotspot-portal <<NGINX
# Default-Server: greift für Captive-Portal-Erkennung (Aufruf per IP oder per
# beliebiger Fremd-Domain über den dnsmasq-Wildcard) und für alle
# Betriebssystem-Connectivity-Checks. Leitet auf die Dashboard-Domain um.
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    location = $CAPTIVE_API_PATH {
        default_type application/captive+json;
        return 200 '{"captive": true, "user-portal-url": "$PORTAL_TARGET"}';
    }

    location ~ ^/(redirect|connecttest\.txt|generate_204|gen_204|hotspot-detect\.html|success\.txt|canonical\.html|ncsi\.txt|library/test/success\.html)$ {
        return 302 $PORTAL_TARGET/;
    }

    location / {
        return 302 $PORTAL_TARGET\$request_uri;
    }
}

# lan-dashboard unter eigener Domain (statt IP:$DASHBOARD_PORT)
server {
    listen 80;
    listen [::]:80;
    server_name $DASHBOARD_DOMAIN;

    location = $CAPTIVE_API_PATH {
        default_type application/captive+json;
        return 200 '{"captive": true, "user-portal-url": "$PORTAL_TARGET"}';
    }

    location / {
        proxy_pass http://127.0.0.1:$DASHBOARD_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}

# Node-RED unter eigener Domain (statt IP:$NODERED_PORT)
server {
    listen 80;
    listen [::]:80;
    server_name $NODERED_DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:$NODERED_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        # Node-RED-Editor braucht WebSockets (Flow-Deploy, Debug-Sidebar)
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
NGINX
    ln -sf /etc/nginx/sites-available/hotspot-portal /etc/nginx/sites-enabled/hotspot-portal
    rm -f /etc/nginx/sites-enabled/default

    echo ">>> Trage $DASHBOARD_DOMAIN und $NODERED_DOMAIN lokal in /etc/hosts ein ..."
    # nginx selbst lauscht nicht auf dnsmasq (das läuft nur auf $WLAN_IFACE,
    # siehe except-interface=lo unten) - ohne diesen Eintrag könnte der Pi
    # seine eigenen server_name-Domains beim nginx-Start/Reload nicht auflösen.
    for d in "$DASHBOARD_DOMAIN" "$NODERED_DOMAIN"; do
        grep -qE "^\s*$HOTSPOT_IP\s+$d\s*$" /etc/hosts || echo "$HOTSPOT_IP $d" >> /etc/hosts
    done

    nginx -t
    systemctl restart nginx

    echo ">>> Fertig installiert. nginx leitet:"
    echo "      http://$DASHBOARD_DOMAIN  -> 127.0.0.1:$DASHBOARD_PORT (lan-dashboard)"
    echo "      http://$NODERED_DOMAIN    -> 127.0.0.1:$NODERED_PORT (Node-RED)"
    echo ">>> Captive-Portal-API erreichbar unter: $CAPTIVE_API_URL"
    echo ">>> Stelle sicher, dass dein Dienst (z.B. Node-RED) auf Port $NODERED_PORT läuft."
    echo ">>> Danach starten mit: sudo $0 start"
}

stop_stale_processes() {
    # Sauber (SIGTERM) statt blind (-9) beenden, und über die eigenen PID-Dateien
    # bzw. eindeutige Config-Pfade identifizieren - NICHT über pauschales "was
    # lauscht gerade auf der Hotspot-IP", da das versehentlich fremde Prozesse
    # treffen könnte.
    if [ -f "$HOSTAPD_PID" ]; then
        kill "$(cat "$HOSTAPD_PID")" 2>/dev/null || true
        rm -f "$HOSTAPD_PID"
    fi
    pkill -f "hostapd.*$HOSTAPD_CONF" 2>/dev/null || true

    if [ -f "$DNSMASQ_PID" ]; then
        kill "$(cat "$DNSMASQ_PID")" 2>/dev/null || true
        rm -f "$DNSMASQ_PID"
    fi
    pkill -f "dnsmasq.*$DNSMASQ_CONF" 2>/dev/null || true

    sleep 1
}

start_hotspot() {
    require_root start
    echo ">>> Entferne $WLAN_IFACE aus der NetworkManager-Verwaltung ..."
    # WICHTIG: Erst hier rausnehmen, nicht dauerhaft in NetworkManager.conf
    # konfigurieren, damit "stop" das Interface am Ende wieder normal nutzbar
    # macht (z.B. für gewöhnliches WLAN-Client-WLAN).
    nmcli device set "$WLAN_IFACE" managed no 2>/dev/null || true
    # Alte NM/netplan-Verbindungsprofile aus früheren Skriptversionen sind
    # nicht mehr nötig, da wir das Interface jetzt selbst verwalten.
    nmcli connection delete hotspot-portal 2>/dev/null || true

    echo ">>> Beende ggf. vorherige hostapd-/dnsmasq-Instanzen ..."
    stop_stale_processes

    echo ">>> Setze WLAN-Regulatory-Domain auf $COUNTRY_CODE ..."
    # Muss VOR dem Hochfahren des Interfaces passieren. Ohne das bleibt der
    # Kernel bei manchen Chipsätzen in der "world"-Domain und verweigert
    # aktives Senden -> hostapd scheitert dann mit "Failed to set channel".
    iw reg set "$COUNTRY_CODE" || echo ">>> WARNUNG: 'iw reg set $COUNTRY_CODE' fehlgeschlagen (ignoriere, ggf. hilft country_code in hostapd.conf trotzdem)."

    echo ">>> Setze $WLAN_IFACE zurück und vergebe feste IP $HOTSPOT_IP ..."
    ip link set "$WLAN_IFACE" down
    ip addr flush dev "$WLAN_IFACE"
    ip link set "$WLAN_IFACE" up
    ip addr add "$HOTSPOT_IP/24" dev "$WLAN_IFACE"

    echo ">>> Schreibe hostapd-Konfiguration ..."
    cat > "$HOSTAPD_CONF" <<HOSTAPD
interface=$WLAN_IFACE
driver=nl80211
ssid=$SSID
country_code=$COUNTRY_CODE
ieee80211d=1
hw_mode=g
channel=$WLAN_CHANNEL
ieee80211n=1
wmm_enabled=1
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=$PASSWORD
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
HOSTAPD

    echo ">>> Starte hostapd ..."
    if ! hostapd -B -P "$HOSTAPD_PID" "$HOSTAPD_CONF"; then
        echo "FEHLER: hostapd konnte nicht gestartet werden. Debug-Ausgabe:"
        hostapd -dd "$HOSTAPD_CONF" 2>&1 | head -n 40
        exit 1
    fi
    sleep 1
    if ! [ -f "$HOSTAPD_PID" ] || ! kill -0 "$(cat "$HOSTAPD_PID")" 2>/dev/null; then
        echo "FEHLER: hostapd ist direkt nach dem Start wieder beendet. Debug-Ausgabe:"
        hostapd -dd "$HOSTAPD_CONF" 2>&1 | head -n 40
        exit 1
    fi

    echo ">>> Warte, bis $WLAN_IFACE als AP bereit ist ..."
    for i in $(seq 1 10); do
        if ip link show "$WLAN_IFACE" 2>/dev/null | grep -q "state UP"; then
            break
        fi
        sleep 0.5
    done

    echo ">>> Schreibe dnsmasq-Konfiguration (DHCP + DNS + Option 114) ..."
    cat > "$DNSMASQ_CONF" <<DNSMASQ
interface=$WLAN_IFACE
bind-interfaces
except-interface=lo

# DHCP für die Hotspot-Clients
dhcp-range=$DHCP_RANGE_START,$DHCP_RANGE_END,255.255.255.0,12h
dhcp-option=option:router,$HOTSPOT_IP
dhcp-option=option:dns-server,$HOTSPOT_IP

# RFC 8910: DHCP Option 114 - teilt Android 11+/iOS 14+/macOS die
# Captive-Portal-API-URL direkt beim DHCP-Handshake mit, ohne DNS/HTTP-Tricks.
dhcp-option=114,"$CAPTIVE_API_URL"

# Unsere eigenen Domains explizit auf die Hotspot-IP auflösen
address=/$DASHBOARD_DOMAIN/$HOTSPOT_IP
address=/$NODERED_DOMAIN/$HOTSPOT_IP

# DNS-Wildcard: JEDE weitere Domain wird ebenfalls auf uns selbst aufgelöst
# (Fallback für Geräte/OS ohne RFC-8910-Unterstützung, z.B. Windows). Die
# beiden expliziten Einträge oben haben Vorrang vor diesem Wildcard.
address=/#/$HOTSPOT_IP
no-resolv
no-poll
DNSMASQ

    dnsmasq --conf-file="$DNSMASQ_CONF" --pid-file="$DNSMASQ_PID"

    echo ">>> Leite jeglichen HTTP-Traffic auf die Portalseite um (Fallback für Clients, die per IP statt per Hostname prüfen) ..."
    iptables -t nat -D PREROUTING -i "$WLAN_IFACE" -p tcp --dport 80 -j DNAT --to-destination "$HOTSPOT_IP:80" 2>/dev/null || true
    iptables -t nat -A PREROUTING -i "$WLAN_IFACE" -p tcp --dport 80 -j DNAT --to-destination "$HOTSPOT_IP:80"

    # HINWEIS: Bewusst KEIN DNAT für Port 443. Ein DNAT in PREROUTING würde das
    # Paket auf $HOTSPOT_IP umschreiben, wodurch es als "lokal zugestellt" gilt
    # und über INPUT statt FORWARD läuft - die REJECT-Regel weiter unten würde
    # es dann nie sehen. Stattdessen wird 443 unten in FORWARD aktiv abgewiesen.

    echo ">>> Blockiere DNS-over-TLS (Port 853) als zusätzliche Absicherung für Geräte, die trotz Option 114 auf Private-DNS-Automatic zurückfallen ..."
    iptables -D FORWARD -i "$WLAN_IFACE" -p tcp --dport 853 -j REJECT --reject-with tcp-reset 2>/dev/null || true
    iptables -I FORWARD -i "$WLAN_IFACE" -p tcp --dport 853 -j REJECT --reject-with tcp-reset

    echo ">>> Blockiere HTTPS aktiv, damit Geräte ohne Option-114-Support schnell auf HTTP-Check ausweichen ..."
    iptables -D FORWARD -i "$WLAN_IFACE" -p tcp --dport 443 -j REJECT --reject-with tcp-reset 2>/dev/null || true
    iptables -I FORWARD -i "$WLAN_IFACE" -p tcp --dport 443 -j REJECT --reject-with tcp-reset

    netfilter-persistent save 2>/dev/null || true

    echo ""
    echo "=========================================="
    echo " Hotspot läuft: SSID '$SSID'"
    echo " Wer sich verbindet, sieht automatisch"
    echo " die Seite von $PORTAL_TARGET"
    echo " Dashboard:  http://$DASHBOARD_DOMAIN"
    echo " Node-RED:   http://$NODERED_DOMAIN"
    echo " Captive-Portal-API: $CAPTIVE_API_URL"
    echo "=========================================="
}

stop_hotspot() {
    require_root stop
    echo ">>> Stoppe Hotspot ..."
    stop_stale_processes

    ip addr flush dev "$WLAN_IFACE" 2>/dev/null || true
    ip link set "$WLAN_IFACE" down 2>/dev/null || true

    iptables -t nat -D PREROUTING -i "$WLAN_IFACE" -p tcp --dport 80 -j DNAT --to-destination "$HOTSPOT_IP:80" 2>/dev/null || true
    iptables -D FORWARD -i "$WLAN_IFACE" -p tcp --dport 443 -j REJECT --reject-with tcp-reset 2>/dev/null || true
    iptables -D FORWARD -i "$WLAN_IFACE" -p tcp --dport 853 -j REJECT --reject-with tcp-reset 2>/dev/null || true
    netfilter-persistent save 2>/dev/null || true

    echo ">>> Gebe $WLAN_IFACE wieder an NetworkManager zurück ..."
    nmcli device set "$WLAN_IFACE" managed yes 2>/dev/null || true
    ip link set "$WLAN_IFACE" up 2>/dev/null || true

    echo ">>> Hotspot gestoppt."
}

case "$1" in
    install) install_packages ;;
    start) start_hotspot ;;
    stop) stop_hotspot ;;
    restart) stop_hotspot; start_hotspot ;;
    *)
        echo "Verwendung: sudo $0 {install|start|stop|restart}"
        exit 1
        ;;
esac
