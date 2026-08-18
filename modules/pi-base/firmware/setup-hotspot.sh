#!/bin/bash
set -e

# ============================================================
# Ubuntu Hotspot with Automatic Captive Portal (No Login)
# ============================================================
# Sets up a Wi-Fi network. Devices that connect automatically
# see the defined webpage (like in a café/airport Wi-Fi).
# There is no "activation" - the page simply opens.
#
# Detection uses TWO parallel mechanisms:
#  1) DHCP Option 114 / RFC 8910 + Captive Portal API (RFC 8908)
#     -> Reliable on Android 11+ and iOS 14+/macOS, without
#        DNS or port hijacking.
#  2) DNS wildcard + HTTP(80) redirect + blocking 443/853
#     -> Fallback for Windows and devices without RFC 8910 support.
#
# IMPORTANT: Why hostapd instead of NetworkManager AP mode:
# On modern Ubuntu, netplan mirrors every connection created via "nmcli"
# in NetworkManager to /etc/netplan/*.yaml.
# The netplan schema for a Wi-Fi AP connection with a fixed address
# does not support a true "ipv4.method=manual" state - when translating back,
# the connection is always set to "ipv4.method=shared" (NetworkManager's own
# internal DHCP/DNS mechanism for tethering). This conflicts with our own
# dnsmasq (duplicate DHCP server, duplicate DNS, unstable activation,
# see "ip-config-unavailable" errors). Any attempt to fix this via nmcli
# will be reset on the next netplan sync. Therefore: remove wlan0 completely
# from NetworkManager control and run the AP directly with hostapd -
# the classic, robust approach for this purpose.
#
# Usage:
#   sudo ./setup-hotspot.sh install   -> Install packages once
#   sudo ./setup-hotspot.sh start     -> Start hotspot
#   sudo ./setup-hotspot.sh stop      -> Stop hotspot
# ============================================================

# ---- CONFIGURATION: Adjust here ----
SSID="Hotspot"
PASSWORD="Password"             # min. 8 characters
WLAN_IFACE="wlan0"              # Check with `ip a`, adjust if needed
WLAN_CHANNEL="6"                # 2.4GHz channel (1, 6, or 11 recommended)
HOTSPOT_IP="192.168.50.1"
DHCP_RANGE_START="192.168.50.10"
DHCP_RANGE_END="192.168.50.100"
COUNTRY_CODE="DE"               # ISO-3166-1 alpha2 country code for Wi-Fi regulatory domain.
                                 # Without a set country, the kernel remains in the "world" domain,
                                 # which on many chipsets refuses active transmission (beaconing)
                                 # on 2.4GHz channels -> hostapd then fails with
                                 # "nl80211: Failed to set channel" / "could not set channel
                                 # for kernel driver", even if the config is otherwise correct.
DASHBOARD_DOMAIN="dashboard.hotspot"            # Domain for lan-dashboard (internal port 5000)
NODERED_DOMAIN="nodered.hotspot"                # Domain for Node-RED (internal port 1880)
DASHBOARD_PORT="5000"
NODERED_PORT="1880"
PORTAL_TARGET="http://$DASHBOARD_DOMAIN"        # Target webpage that opens when connecting
CAPTIVE_API_PATH="/captive-portal-api"          # Path where the RFC8908 JSON API is located
# ---------------------------------------

# SSID/password are NO LONGER prompted during installation, but start
# with the default values above ("Hotspot" / "Password") and can be changed
# afterward via the web interface (Admin mode -> Wi-Fi settings).
# The web interface writes hotspot_config.json in the lan-dashboard directory
# of the configured dashboard user - this is read here and overrides the
# default values above. If the file does not exist (e.g., when directly testing
# this script without install.sh), the default values above continue to apply.
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

# /etc/default/hotspot remains as a manual override option
# (e.g., for systems without a web interface) and takes precedence over JSON.
[ -f /etc/default/hotspot ] && source /etc/default/hotspot

# Allows overriding the country additionally via env COUNTRY_CODE=XX
# (e.g., for manual tests) without modifying /etc/default/hotspot.
COUNTRY_CODE="${COUNTRY_CODE:-DE}"

CAPTIVE_API_URL="http://$DASHBOARD_DOMAIN$CAPTIVE_API_PATH"
DNSMASQ_CONF="/run/dnsmasq-hotspot.conf"
DNSMASQ_PID="/run/dnsmasq-hotspot.pid"
HOSTAPD_CONF="/run/hostapd-hotspot.conf"
HOSTAPD_PID="/run/hostapd-hotspot.pid"

require_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "Please run with sudo: sudo $0 $1"
        exit 1
    fi
}

install_packages() {
    require_root install
    echo ">>> Installing required packages..."
    apt update
    apt install -y hostapd dnsmasq nginx iptables-persistent

    # hostapd and dnsmasq should NOT run globally as a service (would conflict
    # with NetworkManager/systemd-resolved) - we start both specifically
    # only for the hotspot interface, see start_hotspot().
    systemctl disable --now hostapd 2>/dev/null || true
    systemctl disable --now dnsmasq 2>/dev/null || true

    # nginx: serves the portal page (reverse proxy) and the
    # RFC8908 Captive Portal API (static JSON, always "captive": true,
    # as there is no actual activation/login here).
    #
    # NOTE: Intentionally ONLY port 80. HTTPS (443) is actively rejected via
    # iptables with TCP Reset, so devices without RFC8910 support quickly
    # fall back to the unencrypted connectivity check instead of getting
    # stuck on a certificate error from a self-signed 443 vHost.
    cat > /etc/nginx/sites-available/hotspot-portal <<NGINX
# Default server: handles captive portal detection (access via IP or any
# foreign domain via dnsmasq wildcard) and all OS connectivity checks.
# Redirects to the dashboard domain.
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

# lan-dashboard under its own domain (instead of IP:$DASHBOARD_PORT)
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

# Node-RED under its own domain (instead of IP:$NODERED_PORT)
server {
    listen 80;
    listen [::]:80;
    server_name $NODERED_DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:$NODERED_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        # Node-RED editor requires WebSockets (flow deploy, debug sidebar)
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
NGINX
    ln -sf /etc/nginx/sites-available/hotspot-portal /etc/nginx/sites-enabled/hotspot-portal
    rm -f /etc/nginx/sites-enabled/default

    echo ">>> Adding $DASHBOARD_DOMAIN and $NODERED_DOMAIN locally to /etc/hosts ..."
    # nginx itself does not listen on dnsmasq (which only runs on $WLAN_IFACE,
    # see except-interface=lo below) - without this entry, the Pi might not
    # resolve its own server_name domains during nginx start/reload.
    for d in "$DASHBOARD_DOMAIN" "$NODERED_DOMAIN"; do
        grep -qE "^\s*$HOTSPOT_IP\s+$d\s*$" /etc/hosts || echo "$HOTSPOT_IP $d" >> /etc/hosts
    done

    nginx -t
    systemctl restart nginx

    echo ">>> Installation complete. nginx redirects:"
    echo "      http://$DASHBOARD_DOMAIN  -> 127.0.0.1:$DASHBOARD_PORT (lan-dashboard)"
    echo "      http://$NODERED_DOMAIN    -> 127.0.0.1:$NODERED_PORT (Node-RED)"
    echo ">>> Captive Portal API available at: $CAPTIVE_API_URL"
    echo ">>> Ensure your service (e.g., Node-RED) is running on port $NODERED_PORT."
    echo ">>> Then start with: sudo $0 start"
}

stop_stale_processes() {
    # Cleanly terminate (SIGTERM) instead of forcefully (-9), and identify
    # via our own PID files or unique config paths - NOT via a blanket
    # "what is listening on the hotspot IP", as this could accidentally
    # affect foreign processes.
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
    echo ">>> Removing $WLAN_IFACE from NetworkManager control ..."
    # IMPORTANT: Only remove here, not permanently in NetworkManager.conf,
    # so that "stop" can return the interface to normal use afterward
    # (e.g., for regular Wi-Fi client mode).
    nmcli device set "$WLAN_IFACE" managed no 2>/dev/null || true
    # Old NM/netplan connection profiles from earlier script versions
    # are no longer needed, as we now manage the interface ourselves.
    nmcli connection delete hotspot-portal 2>/dev/null || true

    echo ">>> Stopping any previous hostapd/dnsmasq instances ..."
    stop_stale_processes

    echo ">>> Setting Wi-Fi regulatory domain to $COUNTRY_CODE ..."
    # Must happen BEFORE bringing up the interface. Without this, the
    # kernel may remain in the "world" domain on some chipsets and refuse
    # active transmission -> hostapd will then fail with "Failed to set channel".
    iw reg set "$COUNTRY_CODE" || echo ">>> WARNING: 'iw reg set $COUNTRY_CODE' failed (ignoring, country_code in hostapd.conf may still help)."

    echo ">>> Resetting $WLAN_IFACE and assigning static IP $HOTSPOT_IP ..."
    ip link set "$WLAN_IFACE" down
    ip addr flush dev "$WLAN_IFACE"
    ip link set "$WLAN_IFACE" up
    ip addr add "$HOTSPOT_IP/24" dev "$WLAN_IFACE"

    echo ">>> Writing hostapd configuration ..."
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

    echo ">>> Starting hostapd ..."
    if ! hostapd -B -P "$HOSTAPD_PID" "$HOSTAPD_CONF"; then
        echo "ERROR: hostapd could not be started. Debug output:"
        hostapd -dd "$HOSTAPD_CONF" 2>&1 | head -n 40
        exit 1
    fi
    sleep 1
    if ! [ -f "$HOSTAPD_PID" ] || ! kill -0 "$(cat "$HOSTAPD_PID")" 2>/dev/null; then
        echo "ERROR: hostapd terminated immediately after start. Debug output:"
        hostapd -dd "$HOSTAPD_CONF" 2>&1 | head -n 40
        exit 1
    fi

    echo ">>> Waiting for $WLAN_IFACE to be ready as AP ..."
    for i in $(seq 1 10); do
        if ip link show "$WLAN_IFACE" 2>/dev/null | grep -q "state UP"; then
            break
        fi
        sleep 0.5
    done

    echo ">>> Writing dnsmasq configuration (DHCP + DNS + Option 114) ..."
    cat > "$DNSMASQ_CONF" <<DNSMASQ
interface=$WLAN_IFACE
bind-interfaces
except-interface=lo

# DHCP for hotspot clients
dhcp-range=$DHCP_RANGE_START,$DHCP_RANGE_END,255.255.255.0,12h
dhcp-option=option:router,$HOTSPOT_IP
dhcp-option=option:dns-server,$HOTSPOT_IP

# RFC 8910: DHCP Option 114 - tells Android 11+/iOS 14+/macOS the
# Captive Portal API URL directly during the DHCP handshake, without DNS/HTTP tricks.
dhcp-option=114,"$CAPTIVE_API_URL"

# Resolve our own domains explicitly to the hotspot IP
address=/$DASHBOARD_DOMAIN/$HOTSPOT_IP
address=/$NODERED_DOMAIN/$HOTSPOT_IP

# DNS wildcard: ANY other domain is also resolved to ourselves
# (fallback for devices/OS without RFC 8910 support, e.g., Windows).
# The two explicit entries above take precedence over this wildcard.
address=/#/$HOTSPOT_IP
no-resolv
no-poll
DNSMASQ

    dnsmasq --conf-file="$DNSMASQ_CONF" --pid-file="$DNSMASQ_PID"

    echo ">>> Redirecting all HTTP traffic to the portal page (fallback for clients checking via IP instead of hostname) ..."
    iptables -t nat -D PREROUTING -i "$WLAN_IFACE" -p tcp --dport 80 -j DNAT --to-destination "$HOTSPOT_IP:80" 2>/dev/null || true
    iptables -t nat -A PREROUTING -i "$WLAN_IFACE" -p tcp --dport 80 -j DNAT --to-destination "$HOTSPOT_IP:80"

    # NOTE: Intentionally NO DNAT for port 443. A DNAT in PREROUTING would
    # rewrite the packet to $HOTSPOT_IP, causing it to be considered "locally delivered"
    # and processed via INPUT instead of FORWARD - the REJECT rule below would
    # never see it. Instead, 443 is actively rejected in FORWARD below.

    echo ">>> Blocking DNS-over-TLS (port 853) as additional security for devices that fall back to Private DNS Automatic despite Option 114 ..."
    iptables -D FORWARD -i "$WLAN_IFACE" -p tcp --dport 853 -j REJECT --reject-with tcp-reset 2>/dev/null || true
    iptables -I FORWARD -i "$WLAN_IFACE" -p tcp --dport 853 -j REJECT --reject-with tcp-reset

    echo ">>> Actively blocking HTTPS to ensure devices without Option 114 support quickly fall back to HTTP check ..."
    iptables -D FORWARD -i "$WLAN_IFACE" -p tcp --dport 443 -j REJECT --reject-with tcp-reset 2>/dev/null || true
    iptables -I FORWARD -i "$WLAN_IFACE" -p tcp --dport 443 -j REJECT --reject-with tcp-reset

    netfilter-persistent save 2>/dev/null || true

    echo ""
    echo "=========================================="
    echo " Hotspot running: SSID '$SSID'"
    echo " Devices that connect will automatically"
    echo " see the page from $PORTAL_TARGET"
    echo " Dashboard:  http://$DASHBOARD_DOMAIN"
    echo " Node-RED:   http://$NODERED_DOMAIN"
    echo " Captive Portal API: $CAPTIVE_API_URL"
    echo "=========================================="
}

stop_hotspot() {
    require_root stop
    echo ">>> Stopping hotspot ..."
    stop_stale_processes

    ip addr flush dev "$WLAN_IFACE" 2>/dev/null || true
    ip link set "$WLAN_IFACE" down 2>/dev/null || true

    iptables -t nat -D PREROUTING -i "$WLAN_IFACE" -p tcp --dport 80 -j DNAT --to-destination "$HOTSPOT_IP:80" 2>/dev/null || true
    iptables -D FORWARD -i "$WLAN_IFACE" -p tcp --dport 443 -j REJECT --reject-with tcp-reset 2>/dev/null || true
    iptables -D FORWARD -i "$WLAN_IFACE" -p tcp --dport 853 -j REJECT --reject-with tcp-reset 2>/dev/null || true
    netfilter-persistent save 2>/dev/null || true

    echo ">>> Returning $WLAN_IFACE to NetworkManager control ..."
    nmcli device set "$WLAN_IFACE" managed yes 2>/dev/null || true
    ip link set "$WLAN_IFACE" up 2>/dev/null || true

    echo ">>> Hotspot stopped."
}

case "$1" in
    install) install_packages ;;
    start) start_hotspot ;;
    stop) stop_hotspot ;;
    restart) stop_hotspot; start_hotspot ;;
    *)
        echo "Usage: sudo $0 {install|start|stop|restart}"
        exit 1
        ;;
esac
```
