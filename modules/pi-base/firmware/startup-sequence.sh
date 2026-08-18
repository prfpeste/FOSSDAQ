#!/bin/bash
#
# startup-sequence.sh
#
# Executed during boot via systemd (startup-sequence.service) as root.
# Order of operations:
#   1) Create symlinks for ALL already connected Arduinos
#      (find_arduino.sh -a -s) - covers devices already plugged in at boot.
#      Newly connected devices are handled afterward by the udev rule
#      (99-arduino.rules -> find-arduino@.service).
#   2) Start Node-RED and wait for it to respond.
#   3) Start the website (lan-dashboard.service) and wait for it to respond.
#      Intentionally started via "systemctl start" instead of "systemctl enable"
#      (see install.sh) to ensure it starts BEFORE the hotspot rather than
#      uncoordinated in parallel.
#   4) Start the hotspot (setup-hotspot.sh start), whose captive portal
#      points to Node-RED - hence only AFTER Node-RED and the website.
#
# For installation, see the comment at the end of the file / chat instructions.

set -uo pipefail

FIND_ARDUINO="/usr/local/bin/find_arduino.sh"
SETUP_HOTSPOT="/usr/local/bin/setup-hotspot.sh"

# Typically set by /etc/default/startup-sequence (via systemd EnvironmentFile),
# see install.sh. Fallback to "nodered" only for manual test runs.
NODERED_USER="${NODERED_USER:-nodered}"

NODERED_PORT=1880
NODERED_WAIT_SEC=60          # max. wait time for Node-RED before proceeding anyway

DASHBOARD_SERVICE="lan-dashboard.service"
DASHBOARD_PORT=5000
DASHBOARD_WAIT_SEC=30        # max. wait time for the website before proceeding anyway

log() {
    echo "[startup-sequence] $*"
}

# --------------------------------------------------------------------
# 1) Symlinks for all already connected Arduinos
# --------------------------------------------------------------------
log "Waiting for udev (device detection to complete) ..."
udevadm settle --timeout=10 || true

if [ -x "$FIND_ARDUINO" ]; then
    log "Searching for already connected Arduinos and creating symlinks ..."
    "$FIND_ARDUINO" -a -s
else
    log "WARNING: $FIND_ARDUINO not found/executable - skipping symlink creation."
fi

# --------------------------------------------------------------------
# 2) Start Node-RED
# --------------------------------------------------------------------
start_nodered() {
    local nodered_bin
    nodered_bin="$(command -v node-red || true)"
    if [ -z "$nodered_bin" ]; then
        log "ERROR: Command 'node-red' not found (not in PATH of root/systemd)."
        return 1
    fi

    if ! id "$NODERED_USER" >/dev/null 2>&1; then
        log "ERROR: User '$NODERED_USER' does not exist. Run install.sh (new) to create it."
        return 1
    fi

    log "Starting Node-RED in the background as user '$NODERED_USER' (Log: /var/log/node-red/node-red.log) ..."
    mkdir -p /var/log/node-red
    chown "$NODERED_USER":"$NODERED_USER" /var/log/node-red

    # Node-RED intentionally does NOT run as root, but as a dedicated
    # system user ($NODERED_USER, see install.sh). runuser switches
    # UID/GID and automatically sets $HOME to the user's home directory,
    # ensuring Node-RED correctly finds its user directory (~/.node-red)
    # ("could not find user directory" no longer occurs).
    # Absolute path ($nodered_bin) instead of "node-red", as runuser without
    # --login may use a different PATH.
    nohup runuser -u "$NODERED_USER" -- "$nodered_bin" \
        >> /var/log/node-red/node-red.log 2>&1 < /dev/null &
    disown
}

start_nodered

log "Waiting for Node-RED on port $NODERED_PORT (max. ${NODERED_WAIT_SEC}s) ..."
waited=0
while ! curl -s -o /dev/null "http://127.0.0.1:${NODERED_PORT}/"; do
    sleep 1
    waited=$((waited + 1))
    if [ "$waited" -ge "$NODERED_WAIT_SEC" ]; then
        log "WARNING: Node-RED still not responding after ${NODERED_WAIT_SEC}s - proceeding anyway."
        break
    fi
done
[ "$waited" -lt "$NODERED_WAIT_SEC" ] && log "Node-RED is reachable."

# --------------------------------------------------------------------
# 3) Start the website (lan-dashboard)
# --------------------------------------------------------------------
log "Starting website ($DASHBOARD_SERVICE) ..."
if systemctl list-unit-files "$DASHBOARD_SERVICE" >/dev/null 2>&1 && \
   systemctl list-unit-files "$DASHBOARD_SERVICE" | grep -q "$DASHBOARD_SERVICE"; then
    if ! systemctl start "$DASHBOARD_SERVICE"; then
        log "WARNING: $DASHBOARD_SERVICE could not be started - proceeding anyway (see: journalctl -u $DASHBOARD_SERVICE)."
    fi

    log "Waiting for website on port $DASHBOARD_PORT (max. ${DASHBOARD_WAIT_SEC}s) ..."
    waited=0
    while ! curl -s -o /dev/null "http://127.0.0.1:${DASHBOARD_PORT}/"; do
        sleep 1
        waited=$((waited + 1))
        if [ "$waited" -ge "$DASHBOARD_WAIT_SEC" ]; then
            log "WARNING: Website still not responding after ${DASHBOARD_WAIT_SEC}s - proceeding anyway."
            break
        fi
    done
    [ "$waited" -lt "$DASHBOARD_WAIT_SEC" ] && log "Website is reachable."
else
    log "WARNING: $DASHBOARD_SERVICE not installed (run install.sh (new)) - skipping website start."
fi

# --------------------------------------------------------------------
# 4) Start hotspot
# --------------------------------------------------------------------
if [ -x "$SETUP_HOTSPOT" ]; then
    log "Starting hotspot ..."
    "$SETUP_HOTSPOT" start
else
    log "ERROR: $SETUP_HOTSPOT not found/executable - hotspot was NOT started."
    exit 1
fi

log "Startup sequence completed."
