#!/bin/bash
#
# install.sh
#
# Installs Node-RED (official installer if not already present),
# copies find_arduino.sh, setup-hotspot.sh, startup-sequence.sh/.service,
# 99-arduino.rules, and find-arduino@.service to the correct system locations,
# and activates everything. Run once with:
#
#   sudo ./install.sh
#
# IMPORTANT: Must be in the same directory as the above files
# (the script automatically determines its own folder, so you do NOT
# need to "cd" anywhere beforehand).
#
# Skip Node-RED installation (e.g., if already present or custom setup):
#   SKIP_NODERED=1 sudo -E ./install.sh
#
# Skip hotspot packages (hostapd/dnsmasq/nginx/iptables-persistent) installation
# (e.g., if already present):
#   SKIP_HOTSPOT_INSTALL=1 sudo -E ./install.sh
#
# Node-RED palettes (npm packages) to be installed automatically:
# Default is "@flowfuse/node-red-dashboard node-red-node-serialport"
# (Dashboard 2.0 - the old "node-red-dashboard" is deprecated).
# Specify a custom list (space-separated), e.g.:
#   NODERED_PALETTES="@flowfuse/node-red-dashboard node-red-contrib-modbus" sudo -E ./install.sh
# Skip palette installation: NODERED_PALETTES="" sudo -E ./install.sh
#
# Skip dashboard packages (python3-venv/python3-pip) installation
# (e.g., if already present):
#   SKIP_DASHBOARD_INSTALL=1 sudo -E ./install.sh
#
# System user under which the dashboard (lan-dashboard) runs. Default is "pi",
# matching lan-dashboard.service/README. Use a custom user, e.g.:
#   DASHBOARD_USER=web sudo -E ./install.sh
#
# Hotspot name (SSID), hotspot password, and admin password for the dashboard
# are NO LONGER prompted during installation. They start with the default
# values "Hotspot" / "Password" / "admin" and can be changed afterward via
# the web interface (Admin mode).

set -euo pipefail

SKIP_NODERED="${SKIP_NODERED:-0}"
SKIP_HOTSPOT_INSTALL="${SKIP_HOTSPOT_INSTALL:-0}"   # e.g., if hostapd/dnsmasq/nginx are already manually configured
SKIP_DASHBOARD_INSTALL="${SKIP_DASHBOARD_INSTALL:-0}"   # e.g., if python3-venv/python3-pip are already present
NODERED_USER="${NODERED_USER:-nodered}"   # System user under which Node-RED runs (NOT root)
DASHBOARD_USER="${DASHBOARD_USER:-pi}"    # System user under which the dashboard (lan-dashboard) runs
DASHBOARD_DIR="/home/$DASHBOARD_USER/lan-dashboard"
# Space-separated list of npm packages to install in ~/.node-red of the
# Node-RED user (will appear in the palette afterward).
# node-red-dashboard (Dashboard 1.0) has been officially deprecated since June 2024
# (no further development) - @flowfuse/node-red-dashboard (Dashboard 2.0)
# is the actively maintained successor, hence set as default.
# Leave empty (NODERED_PALETTES="") to skip palette installation.
NODERED_PALETTES="${NODERED_PALETTES:-@flowfuse/node-red-dashboard node-red-node-serialport}"

if [ "$EUID" -ne 0 ]; then
    echo "Please run with sudo: sudo $0"
    exit 1
fi

# Directory where this script (and the other files) are located
SRC_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
echo ">>> Source directory: $SRC_DIR"
cd "$SRC_DIR"

require_file() {
    if [ ! -f "$1" ]; then
        echo "ERROR: $1 not found in $SRC_DIR - aborting."
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
    echo ">>> SKIP_NODERED=1 set - skipping Node-RED installation."
elif command -v node-red >/dev/null 2>&1; then
    echo ">>> Node-RED is already installed - skipping installation."
else
    echo ">>> Installing Node.js + Node-RED (official installer) ..."
    # Official installer from nodered.org. --confirm-install skips the
    # interactive yes/no prompt, --confirm-root allows execution as root
    # (this script is already running via sudo). Node-RED will NOT run as root later -
    # see user creation below.
    bash <(curl -sL https://raw.githubusercontent.com/node-red/linux-installers/master/deb/update-nodejs-and-nodered) --confirm-install --confirm-root
fi

echo ">>> Checking/creating system user '$NODERED_USER' for Node-RED ..."
if id "$NODERED_USER" >/dev/null 2>&1; then
    echo ">>> User '$NODERED_USER' already exists."
else
    # --system: system user (not a regular login user, no password prompt)
    # --create-home: creates home directory where Node-RED stores its
    #                user directory (~/.node-red with flows.json, nodes, etc.)
    # --shell nologin: no interactive login possible
    # --groups dialout: if Node-RED flows (serial nodes) need direct access
    #                   to /dev/ttyACM*/ttyUSB*
    useradd --system --create-home --home-dir "/home/$NODERED_USER" \
        --shell /usr/sbin/nologin --groups dialout "$NODERED_USER"
    echo ">>> User '$NODERED_USER' created (Home: /home/$NODERED_USER, group: dialout)."
fi

# Log directory owned by the Node-RED user, in case they need to write to it
# (e.g., during manual tests outside the startup script).
mkdir -p /var/log/node-red
chown "$NODERED_USER":"$NODERED_USER" /var/log/node-red

NODERED_HOME="/home/$NODERED_USER"
NODERED_DIR="$NODERED_HOME/.node-red"

if [ -n "$NODERED_PALETTES" ]; then
    echo ">>> Installing Node-RED palettes: $NODERED_PALETTES"
    mkdir -p "$NODERED_DIR"
    chown "$NODERED_USER":"$NODERED_USER" "$NODERED_DIR"

    # ~/.node-red requires a package.json so that "npm install" registers the
    # packages as dependencies there (Node-RED recognizes them as palettes on startup).
    # If none exists yet (e.g., because Node-RED has never been started here),
    # create a minimal one.
    #
    # IMPORTANT: Do NOT use "npm init -y" - npm derives the default name from
    # the directory name, and ".node-red" starts with a dot, which is not a valid
    # npm package name ("npm error invalid name"). The package.json will NOT be
    # created, and "npm install" will fail afterward. Instead, write the file
    # directly with a valid name.
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

    # Install as NODERED_USER (not root) to ensure file permissions in
    # ~/.node-red are correct - just like Node-RED itself will run as this
    # user later (see startup-sequence.sh).
    if ! runuser -u "$NODERED_USER" -- bash -c "cd '$NODERED_DIR' && npm install --no-audit --no-fund $NODERED_PALETTES"; then
        echo "WARNING: Installation of at least one palette failed - please check the output above."
        echo "Node-RED will still start, but the affected node(s) may be missing from the palette."
    fi
else
    echo ">>> NODERED_PALETTES is empty - skipping palette installation."
fi

echo ">>> Copying scripts to /usr/local/bin ..."
cp find_arduino.sh setup-hotspot.sh startup-sequence.sh /usr/local/bin/
chmod +x /usr/local/bin/find_arduino.sh /usr/local/bin/setup-hotspot.sh /usr/local/bin/startup-sequence.sh

# ==========================================================================
# Set up dashboard (lan-dashboard)
#
# NOT enabled via "systemctl enable" to start independently - otherwise,
# systemd would start it in parallel/uncoordinated with the hotspot.
# Instead, startup-sequence.sh starts it explicitly via "systemctl start"
# and waits for it to respond BEFORE the hotspot goes online
# (see startup-sequence.sh).
# ==========================================================================
echo ">>> Setting up dashboard (lan-dashboard) ..."

if [ "$SKIP_DASHBOARD_INSTALL" -eq 1 ]; then
    echo ">>> SKIP_DASHBOARD_INSTALL=1 set - skipping package installation (python3-venv/python3-pip)."
else
    echo ">>> Installing Python dependencies (python3-venv, python3-pip) ..."
    apt update
    apt install -y python3-venv python3-pip
fi

echo ">>> Checking/creating system user '$DASHBOARD_USER' for the dashboard ..."
if id "$DASHBOARD_USER" >/dev/null 2>&1; then
    echo ">>> User '$DASHBOARD_USER' already exists."
else
    # Regular user with home directory (not --system), since "pi" on a
    # real Raspberry Pi usually already exists - this branch only applies
    # to systems where it is missing (e.g., pure Ubuntu).
    useradd --create-home --shell /bin/bash "$DASHBOARD_USER"
    echo ">>> User '$DASHBOARD_USER' created (Home: /home/$DASHBOARD_USER)."
fi

echo ">>> Copying dashboard files to $DASHBOARD_DIR ..."
mkdir -p "$DASHBOARD_DIR"
for item in app.py requirements.txt README.md templates static; do
    cp -r "lan-dashboard/$item" "$DASHBOARD_DIR/"
done

# Runtime data (buttons, design, admin password hash) is only copied
# if not already present - this ensures that re-running install.sh does
# not overwrite changes made via the web interface.
for datafile in buttons.json settings.json admin_config.json hotspot_config.json; do
    if [ -f "$DASHBOARD_DIR/$datafile" ]; then
        echo ">>> $datafile already exists in $DASHBOARD_DIR - keeping existing file."
    elif [ -f "lan-dashboard/$datafile" ]; then
        cp "lan-dashboard/$datafile" "$DASHBOARD_DIR/"
    fi
done
mkdir -p "$DASHBOARD_DIR/static/uploads"

chown -R "$DASHBOARD_USER":"$DASHBOARD_USER" "$DASHBOARD_DIR"

echo ">>> Setting up Python environment (venv) for the dashboard ..."
if [ ! -x "$DASHBOARD_DIR/venv/bin/python" ]; then
    runuser -u "$DASHBOARD_USER" -- bash -c "cd '$DASHBOARD_DIR' && python3 -m venv venv"
fi
runuser -u "$DASHBOARD_USER" -- bash -c "cd '$DASHBOARD_DIR' && venv/bin/pip install --no-input --quiet --upgrade pip && venv/bin/pip install --no-input --quiet -r requirements.txt"

echo ">>> Checking/creating .env (Secret Key) for the dashboard ..."
if [ -f "$DASHBOARD_DIR/.env" ]; then
    echo ">>> $DASHBOARD_DIR/.env already exists - leaving it unchanged."
else
    # Admin password is NO LONGER prompted: starts with the default value "admin"
    # (see app.py) and can be changed afterward via the web interface.
    # Optionally, it can still be predefined via DASHBOARD_ADMIN_PASSWORD.
    DASHBOARD_SECRET_KEY="$("$DASHBOARD_DIR/venv/bin/python" -c 'import secrets; print(secrets.token_hex(32))')"

    {
        echo "SECRET_KEY=$DASHBOARD_SECRET_KEY"
        if [ -n "${DASHBOARD_ADMIN_PASSWORD:-}" ]; then
            echo "ADMIN_PASSWORD=$DASHBOARD_ADMIN_PASSWORD"
        fi
    } > "$DASHBOARD_DIR/.env"
    chown "$DASHBOARD_USER":"$DASHBOARD_USER" "$DASHBOARD_DIR/.env"
    chmod 600 "$DASHBOARD_DIR/.env"
fi

echo ">>> Setting up sudo permissions (shutdown/restart button, Wi-Fi settings) ..."
# The dashboard runs as $DASHBOARD_USER (not root) and needs root permissions
# for shutdown/restart and to apply changed Wi-Fi settings immediately -
# without a password prompt, as no interactive terminal is available.
cat > /etc/sudoers.d/lan-dashboard <<EOF
$DASHBOARD_USER ALL=(root) NOPASSWD: /sbin/shutdown, /usr/local/bin/setup-hotspot.sh restart
EOF
chmod 440 /etc/sudoers.d/lan-dashboard
visudo -c -f /etc/sudoers.d/lan-dashboard

echo ">>> Installing systemd unit for the dashboard ..."
# lan-dashboard.service is hardcoded for user/path "pi" - adjust to
# $DASHBOARD_USER/$DASHBOARD_DIR during installation (source file remains
# unchanged, only the installed copy is modified).
sed -e "s#/home/pi/lan-dashboard#$DASHBOARD_DIR#g" \
    -e "s/^User=pi$/User=$DASHBOARD_USER/" \
    lan-dashboard/lan-dashboard.service > /etc/systemd/system/lan-dashboard.service

echo ">>> Hotspot name/password are NO LONGER prompted - default values"
echo "    'Hotspot' / 'Password' from $DASHBOARD_DIR/hotspot_config.json apply,"
echo "    changeable via the web interface (Admin mode -> Wi-Fi settings)."

# ==========================================================================
# Determine Wi-Fi interface for the hotspot
#
# setup-hotspot.sh has "wlan0" hardcoded as the default WLAN_IFACE, but reads
# /etc/default/hotspot at the beginning and prioritizes that file over the default.
# Therefore, we do NOT need to modify setup-hotspot.sh - it is sufficient to
# write the detected interface name there.
#
# Manually enforce (e.g., with multiple Wi-Fi adapters or incorrect detection):
#   WLAN_IFACE=wlp2s0 sudo -E ./install.sh
# ==========================================================================
if [ -n "${WLAN_IFACE:-}" ]; then
    echo ">>> WLAN_IFACE=$WLAN_IFACE was manually specified - skipping automatic detection."
else
    echo ">>> Searching for connected Wi-Fi interface ..."
    # /sys/class/net/*/wireless only exists for actual Wi-Fi interfaces
    # (unlike "iw dev", which may be missing if the "iw" package is not yet
    # installed - hence no tool dependency here).
    mapfile -t WLAN_CANDIDATES < <(
        for w in /sys/class/net/*/wireless; do
            [ -d "$w" ] || continue
            basename "$(dirname "$w")"
        done | sort
    )

    case "${#WLAN_CANDIDATES[@]}" in
        0)
            echo "ERROR: No Wi-Fi interface found (no entry under /sys/class/net/*/wireless)."
            echo "       Is a Wi-Fi adapter connected/activated? Driver loaded (see 'ip a')?"
            echo "       Alternatively, specify the interface manually: WLAN_IFACE=<name> sudo -E $0"
            exit 1
            ;;
        1)
            WLAN_IFACE="${WLAN_CANDIDATES[0]}"
            echo ">>> Wi-Fi interface detected: $WLAN_IFACE"
            ;;
        *)
            echo "ERROR: Multiple Wi-Fi interfaces found (${WLAN_CANDIDATES[*]}) - automatic selection not unique."
            echo "       Please specify the desired interface manually, e.g.:"
            echo "       WLAN_IFACE=${WLAN_CANDIDATES[0]} sudo -E $0"
            exit 1
            ;;
    esac
fi

echo ">>> Writing WLAN_IFACE=$WLAN_IFACE to /etc/default/hotspot ..."
# Replace existing WLAN_IFACE line (from a previous install.sh run),
# otherwise append - the rest of /etc/default/hotspot (e.g., manually set
# SSID/PASSWORD overrides) remains untouched.
touch /etc/default/hotspot
if grep -q '^WLAN_IFACE=' /etc/default/hotspot 2>/dev/null; then
    sed -i "s/^WLAN_IFACE=.*/WLAN_IFACE=$WLAN_IFACE/" /etc/default/hotspot
else
    echo "WLAN_IFACE=$WLAN_IFACE" >> /etc/default/hotspot
fi

if [ "$SKIP_HOTSPOT_INSTALL" -eq 1 ]; then
    echo ">>> SKIP_HOTSPOT_INSTALL=1 set - skipping hotspot package installation (hostapd/dnsmasq/nginx)."
else
    echo ">>> Installing hotspot dependencies (hostapd, dnsmasq, nginx, iptables-persistent) ..."
    # IMPORTANT: Without this step, the 'hostapd' command will be missing
    # ("command not found") during boot, as startup-sequence.sh -> setup-hotspot.sh
    # assumes the packages are already present.
    /usr/local/bin/setup-hotspot.sh install
fi

echo ">>> Writing configuration (Node-RED/dashboard user) to /etc/default/startup-sequence ..."
cat > /etc/default/startup-sequence <<EOF
# Read by startup-sequence.sh via systemd EnvironmentFile.
NODERED_USER=$NODERED_USER
# DASHBOARD_USER is passed to setup-hotspot.sh (as environment of the
# startup-sequence.service process) so that the correct hotspot_config.json
# is found under /home/$DASHBOARD_USER/lan-dashboard/ during boot.
DASHBOARD_USER=$DASHBOARD_USER
EOF

echo ">>> Copying systemd unit for boot startup sequence ..."
cp startup-sequence.service /etc/systemd/system/

echo ">>> Copying udev rule and hotplug service ..."
cp 99-arduino.rules /etc/udev/rules.d/
cp find-arduino_.service /etc/systemd/system/find-arduino@.service

echo ">>> Reloading udev rules ..."
udevadm control --reload
udevadm trigger

echo ">>> Reloading systemd and enabling startup-sequence.service ..."
systemctl daemon-reload
systemctl enable startup-sequence.service
# lan-dashboard.service is intentionally NOT enabled via "systemctl enable":
# startup-sequence.sh starts it explicitly (before the hotspot) to ensure
# the correct order during boot (see comment there).

if [ -d /root/.node-red ] && [ ! -d "/home/$NODERED_USER/.node-red/node_modules" ]; then
    echo ""
    echo "NOTE: There appears to be old data in /root/.node-red from a"
    echo "previous run (as root). Node-RED now runs as '$NODERED_USER' and"
    echo "looks for its user directory under /home/$NODERED_USER/.node-red - old"
    echo "flows will NOT be automatically transferred. To manually copy, e.g.:"
    echo "  sudo cp -r /root/.node-red/. /home/$NODERED_USER/.node-red/"
    echo "  sudo chown -R $NODERED_USER:$NODERED_USER /home/$NODERED_USER/.node-red"
fi

echo ""
echo "=========================================="
echo " Installation complete."
echo " Test without reboot: sudo systemctl start startup-sequence.service"
echo " Check status:        systemctl status startup-sequence.service"
echo " View logs:           journalctl -u startup-sequence.service -e"
echo " Dashboard (lan-dashboard): http://<Pi-IP>:5000 - Status: systemctl status lan-dashboard.service"
echo "=========================================="
```
