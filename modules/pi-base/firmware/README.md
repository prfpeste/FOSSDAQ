# firmware/

This is the top-level directory of the FOSSDAQ Raspberry Pi setup. It turns a
Pi into a self-contained field-data-acquisition box: it finds connected
Arduinos, runs Node-RED (with custom "fossdaq" nodes to talk to those
Arduinos), serves a small local website (`lan-dashboard`), and finally opens a
Wi-Fi hotspot with a captive portal that points visitors at that dashboard.  

For installation details see `docs/hot_to_setup.md`.

Subdirectories have their own `README.md` with more detail:
- **`Custom-Nodes/`** – custom Node-RED nodes for talking to Arduinos over
  serial (`fossdaq-init`, `fossdaq-input`, `fossdaq-output`). **This is where
  you add support for new Arduino/board types** (see
  `Custom-Nodes/README.md`, section on `fossdaq-config.js`).
- **`lan-dashboard/`** – the Flask web app that shows the button/link
  dashboard reachable from the hotspot.

## Files in this directory

| File | Purpose | What you can edit |
|---|---|---|
| `install.sh` | One-shot installer. Installs Node-RED, Node-RED palettes, the custom fossdaq nodes, the dashboard (venv, systemd service, sudoers), the hotspot packages, and all systemd units/udev rules. Run as `sudo ./install.sh` from this directory. | Env vars at invocation time: `SKIP_NODERED`, `SKIP_HOTSPOT_INSTALL`, `SKIP_DASHBOARD_INSTALL`, `NODERED_USER`, `DASHBOARD_USER`, `NODERED_PALETTES`, `WLAN_IFACE`, `DASHBOARD_ADMIN_PASSWORD`. Edit the script itself only if you need to change *what* gets installed/copied. |
| `uninstall.sh` | Reverts everything `install.sh` did (stops/disables services, removes hotspot config, deletes copied files, optionally removes users/packages). Run as `sudo ./uninstall.sh`. | Env vars: `DASHBOARD_USER`, `NODERED_USER`, `KEEP_USERS=1`, `KEEP_PACKAGES=1`. |
| `startup-sequence.sh` | Runs at boot (via `startup-sequence.service`). Order: create symlinks for already-connected Arduinos → start Node-RED → start `lan-dashboard` → start the hotspot. | `NODERED_PORT`, `NODERED_WAIT_SEC`, `DASHBOARD_PORT`, `DASHBOARD_WAIT_SEC` constants near the top if timings need to change. `NODERED_USER` is normally supplied via `/etc/default/startup-sequence`, not edited here. |
| `startup-sequence.service` | systemd unit that runs `startup-sequence.sh` at boot as root. | `TimeoutStartSec` if the sequence needs longer; otherwise leave as-is (installed as-is by `install.sh`). |
| `setup-hotspot.sh` | Creates/tears down the Wi-Fi hotspot + captive portal (hostapd + dnsmasq + nginx + iptables). Subcommands: `install`, `start`, `stop`, `restart`. | The `# ---- CONFIGURATION: Adjust here ----` block near the top: `SSID`, `PASSWORD`, `WLAN_IFACE`, `WLAN_CHANNEL`, `HOTSPOT_IP`, DHCP range, `COUNTRY_CODE`, `DASHBOARD_DOMAIN`, `NODERED_DOMAIN`, ports. In practice SSID/password are overridden at runtime by `lan-dashboard/hotspot_config.json` (settable from the dashboard's admin UI), so you usually don't need to edit this file directly. |
| `find_arduino.sh` | Identifies which serial port (`/dev/ttyACM*`/`/dev/ttyUSB*`) an Arduino is on by sending `serveID` and matching the reply, and can create a friendly symlink under `/dev/arduino/<ID>`. | `KNOWN_IDS` array — **add the ID string your Arduino sketch replies with here** so it gets recognized. Also `BAUDRATE`, `IDENTIFY_CMD`, `TIMEOUT_SEC`, `BOOT_WAIT_SEC`, default `SYMLINK_DIR` if your setup differs. |
| `99-arduino.rules` | udev rule: when a new `ttyACM*`/`ttyUSB*` device appears, it triggers `find-arduino@<device>.service`. | Only edit if you need to match different device classes; normally left untouched. |
| `find-arduino_.service` | systemd template unit (`find-arduino@.service` once installed) started by the udev rule for each newly plugged-in serial device; runs `find_arduino.sh -s -p /dev/%i`. | Rarely needs edits; change if you want different `find_arduino.sh` flags on hotplug. |

## Where to make the changes you're probably looking for

- **Add a new Arduino/board type (channels, sensors, actuators):** edit
  `Custom-Nodes/fossdaq-config.js`. See `Custom-Nodes/README.md`.
- **Teach `find_arduino.sh` to recognize a new board's identity string:**
  add it to the `KNOWN_IDS` array in `find_arduino.sh`.
- **Change hotspot Wi-Fi name/password/IP range:** either use the dashboard's
  admin UI (writes `lan-dashboard/hotspot_config.json`), or edit the
  configuration block in `setup-hotspot.sh`.
- **Change dashboard buttons/links:** use the dashboard's admin UI (writes
  `lan-dashboard/buttons.json`), see `lan-dashboard/README.md`.
- **Change which system users things run as:** `DASHBOARD_USER` /
  `NODERED_USER` environment variables passed to `install.sh`.
