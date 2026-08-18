#!/bin/bash
#
# uninstall.sh
#
# Reverts everything set up by install.sh: stops and disables all services,
# removes hotspot network settings (hostapd/dnsmasq/nginx/iptables),
# deletes all copied scripts, systemd units, udev rules, sudo permissions,
# and—unless specified otherwise—also the website/Node-RED directories and
# the system users created for them.
#
# Run once with:
#   sudo ./uninstall.sh
#
# No confirmation is requested—the script runs fully automatically.
#
# Options (via environment variables, same names as in install.sh):
#   DASHBOARD_USER=web sudo -E ./uninstall.sh   -> if a different user than "pi"
#                                                   was used during installation
#   NODERED_USER=xyz sudo -E ./uninstall.sh     -> if a different Node-RED user
#                                                   was used during installation
#   KEEP_USERS=1 sudo -E ./uninstall.sh         -> Do NOT delete system users (pi/nodered)
#                                                   (only their hotspot/Node-RED data)
#   KEEP_PACKAGES=1 sudo -E ./uninstall.sh      -> Do NOT uninstall hostapd/dnsmasq/nginx/
#                                                   Node-RED/Node.js, only remove configuration
# ============================================================

set -uo pipefail   # intentionally WITHOUT "-e": a single missing file or
                    # already inactive service should not abort the uninstallation -
                    # as much as possible should be cleaned up

if [ "$EUID" -ne 0 ]; then
    echo "Please run with sudo: sudo $0"
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
echo " Uninstallation starting ..."
echo " DASHBOARD_USER=$DASHBOARD_USER  NODERED_USER=$NODERED_USER"
echo "=========================================="

# ------------------------------------------------------------------
# 1) Stop hotspot and reset network state
# ------------------------------------------------------------------
echo ">>> Stopping running hotspot (if active) ..."
if [ -x /usr/local/bin/setup-hotspot.sh ]; then
    /usr/local/bin/setup-hotspot.sh stop 2>/dev/null || true
elif [ -x "$(dirname "$(readlink -f "$0")")/setup-hotspot.sh" ]; then
    "$(dirname "$(readlink -f "$0")")/setup-hotspot.sh" stop 2>/dev/null || true
fi

echo ">>> Terminating any remaining hostapd/dnsmasq processes ..."
pkill -f "hostapd.*hostapd-hotspot.conf" 2>/dev/null || true
pkill -f "dnsmasq.*dnsmasq-hotspot.conf" 2>/dev/null || true

echo ">>> Removing iptables rules ..."
iptables -t nat -D PREROUTING -i "$WLAN_IFACE" -p tcp --dport 80 -j DNAT --to-destination "$HOTSPOT_IP:80" 2>/dev/null || true
iptables -D FORWARD -i "$WLAN_IFACE" -p tcp --dport 443 -j REJECT --reject-with tcp-reset 2>/dev/null || true
iptables -D FORWARD -i "$WLAN_IFACE" -p tcp --dport 853 -j REJECT --reject-with tcp-reset 2>/dev/null || true
netfilter-persistent save 2>/dev/null || true

echo ">>> Returning $WLAN_IFACE to NetworkManager control ..."
nmcli device set "$WLAN_IFACE" managed yes 2>/dev/null || true
nmcli connection delete hotspot-portal 2>/dev/null || true
ip addr flush dev "$WLAN_IFACE" 2>/dev/null || true

# ------------------------------------------------------------------
# 2) Stop, disable, and remove systemd services and unit files
# ------------------------------------------------------------------
echo ">>> Stopping and disabling systemd services ..."
for svc in startup-sequence.service lan-dashboard.service find-arduino@.service; do
    systemctl stop "$svc" 2>/dev/null || true
    systemctl disable "$svc" 2>/dev/null || true
done
systemctl disable --now hostapd 2>/dev/null || true
systemctl disable --now dnsmasq 2>/dev/null || true

echo ">>> Removing systemd unit files ..."
rm -f /etc/systemd/system/startup-sequence.service
rm -f /etc/systemd/system/lan-dashboard.service
rm -f /etc/systemd/system/find-arduino@.service
systemctl daemon-reload
systemctl reset-failed 2>/dev/null || true

# ------------------------------------------------------------------
# 3) Remove udev rules
# ------------------------------------------------------------------
echo ">>> Removing udev rule ..."
rm -f /etc/udev/rules.d/99-arduino.rules
udevadm control --reload 2>/dev/null || true
udevadm trigger 2>/dev/null || true

# ------------------------------------------------------------------
# 4) Remove nginx configuration
# ------------------------------------------------------------------
echo ">>> Removing nginx configuration ..."
rm -f /etc/nginx/sites-enabled/hotspot-portal
rm -f /etc/nginx/sites-available/hotspot-portal
# Re-enable Ubuntu default page if it still exists, so nginx
# does not end up without any enabled site after uninstallation
if [ -f /etc/nginx/sites-available/default ] && [ ! -e /etc/nginx/sites-enabled/default ]; then
    ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default
fi
nginx -t 2>/dev/null && systemctl restart nginx 2>/dev/null || systemctl stop nginx 2>/dev/null || true

# ------------------------------------------------------------------
# 5) Remove custom domains from /etc/hosts
# ------------------------------------------------------------------
echo ">>> Removing dashboard.hotspot/nodered.hotspot from /etc/hosts ..."
sed -i -E '/\s(dashboard\.hotspot|nodered\.hotspot)\s*$/d' /etc/hosts

# ------------------------------------------------------------------
# 6) Remove sudo permissions
# ------------------------------------------------------------------
echo ">>> Removing sudoers entry ..."
rm -f /etc/sudoers.d/lan-dashboard

# ------------------------------------------------------------------
# 7) Remove copied scripts and runtime/configuration files
# ------------------------------------------------------------------
echo ">>> Removing scripts from /usr/local/bin ..."
rm -f /usr/local/bin/find_arduino.sh
rm -f /usr/local/bin/setup-hotspot.sh
rm -f /usr/local/bin/startup-sequence.sh

echo ">>> Removing /etc/default configuration files ..."
rm -f /etc/default/startup-sequence
rm -f /etc/default/hotspot

echo ">>> Removing orphaned runtime files in /run ..."
rm -f /run/dnsmasq-hotspot.conf /run/dnsmasq-hotspot.pid
rm -f /run/hostapd-hotspot.conf /run/hostapd-hotspot.pid

# ------------------------------------------------------------------
# 8) Remove website (lan-dashboard)
# ------------------------------------------------------------------
echo ">>> Removing website directory $DASHBOARD_DIR ..."
rm -rf "$DASHBOARD_DIR"

# ------------------------------------------------------------------
# 9) Remove Node-RED data
# ------------------------------------------------------------------
echo ">>> Removing Node-RED user directory /home/$NODERED_USER/.node-red ..."
rm -rf "/home/$NODERED_USER/.node-red"
rm -rf "/var/log/node-red"

# ------------------------------------------------------------------
# 10) Remove system users (including home directories), unless KEEP_USERS=1
# ------------------------------------------------------------------
if [ "$KEEP_USERS" -eq 1 ]; then
    echo ">>> KEEP_USERS=1 set - system users '$DASHBOARD_USER' and '$NODERED_USER' are retained."
else
    echo ">>> Removing system user '$NODERED_USER' (if present) ..."
    if id "$NODERED_USER" >/dev/null 2>&1; then
        userdel --remove "$NODERED_USER" 2>/dev/null || echo "WARNING: User '$NODERED_USER' could not be fully removed (possibly still running processes)."
    fi

    echo ">>> Removing system user '$DASHBOARD_USER' (if present and not a regular login user you want to keep) ..."
    if id "$DASHBOARD_USER" >/dev/null 2>&1; then
        userdel --remove "$DASHBOARD_USER" 2>/dev/null || echo "WARNING: User '$DASHBOARD_USER' could not be fully removed (possibly still running processes or it is your own login user)."
    fi
fi

# ------------------------------------------------------------------
# 11) Optionally: Remove installed packages
# ------------------------------------------------------------------
if [ "$KEEP_PACKAGES" -eq 1 ]; then
    echo ">>> KEEP_PACKAGES=1 set - packages (hostapd/dnsmasq/nginx/Node-RED/Node.js) remain installed."
else
    echo ">>> Removing packages hostapd, dnsmasq, nginx, iptables-persistent ..."
    apt purge -y hostapd dnsmasq nginx nginx-common iptables-persistent 2>/dev/null || true
    apt autoremove -y 2>/dev/null || true

    echo ">>> Removing Node-RED and Node.js (globally installed) ..."
    npm uninstall -g --unsafe-perm node-red 2>/dev/null || true
fi

echo ""
echo "=========================================="
echo " Uninstallation complete."
echo " Wi-Fi interface $WLAN_IFACE is back under NetworkManager control."
echo " A system reboot is recommended to ensure no old processes/"
echo " network states remain active."
echo "=========================================="
