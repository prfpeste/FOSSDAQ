# Installation Guide

This guide walks through installing the full stack on a fresh
Raspberry Pi OS (recommended) (or Ubuntu) machine:

- **Node-RED** (flow automation)
- **lan-dashboard** (Flask web control panel)
- **Wi-Fi hotspot with captive portal** (hostapd + dnsmasq + nginx)
- **Arduino auto-detection** (udev + symlinks)
- A **boot sequence** that starts everything in the right order

Everything is orchestrated by a single script, `install.sh`.

---

## 1. Requirements

- freshly installed Raspberry Pi OS (recommended) (or Ubuntu 22.04/24.04) with a network connection for the
  install step
- A Wi-Fi adapter that supports AP (access point) mode. Raspberry PIs come with a builtin one.
- Root access (`sudo`)

## 2. What gets installed

| Component | Purpose | Runs as |
|---|---|---|
| Node-RED | Flow automation / dashboard backend | dedicated user `nodered` |
| lan-dashboard | Flask web control panel with buttons linking to local pages | dedicated user `pi` (configurable) |
| hostapd + dnsmasq | Wi-Fi access point + DHCP/DNS | root, only while the hotspot is active |
| nginx | Reverse proxy + captive portal detection endpoint | root |
| `startup-sequence.service` | Orchestrates boot order: Arduino symlinks → Node-RED → lan-dashboard → hotspot | root |
| `find-arduino@.service` + udev rule | Detects Arduino boards as they're plugged in and creates stable symlinks | root |

## 3. Run the installer

```bash
sudo apt update && sudo apt upgrade -y
rm -rf firmware/
git clone --no-checkout --depth 1 --branch Alexander_Gschlecht_Test https://github.com/prfpeste/FOSSDAQ.git
cd FOSSDAQ
git sparse-checkout init --cone
git sparse-checkout set modules/pi-base/firmware
git checkout
cd ..
mv FOSSDAQ/modules/pi-base/firmware ~/firmware
rm -rf FOSSDAQ/
rm firmware/README.md
sudo bash firmware/install.sh
sudo reboot now
```
Running these commands will setup everything nearly automatically. The installer will ask for these inputs:

|Name|User Input|
|---|---|
|install PI specific Nodes|y -> ENTER|
|settings file|ENTER|
|send usage data|no -> ENTER|
|setup user security|no -> ENTER|
|setup projects|no -> ENTER|
|Name for flows file|ENTER|
|Passphrase|ENTER|
|-|default -> ENTER|
|-|monaco (default) -> ENTER|

The `install.sh` script is idempotent — re-running it later (e.g. after an update) is
safe and will not overwrite data you've already configured through the web
UI (buttons, settings, admin password, hotspot config).

### 3.1 Wi-Fi interface detection

`install.sh` automatically detects the Wi-Fi interface to use for the
hotspot by scanning `/sys/class/net/*/wireless` — no `iw` or `nmcli`
required.

- **Exactly one Wi-Fi interface found** → it's used automatically, and the
  name is written to `/etc/default/hotspot` (which `setup-hotspot.sh` reads
  at start, overriding its hardcoded `wlan0` default).
- **None found** → installation aborts with an error. Make sure a Wi-Fi
  adapter is plugged in, enabled, and its driver is loaded (`ip a` should
  list it).
- **More than one found** (e.g. onboard Wi-Fi + USB dongle) → installation
  aborts, since automatic selection wouldn't be unambiguous. Pick the
  interface manually (see below).

To skip auto-detection or force a specific interface:

```bash
WLAN_IFACE=wlp2s0 sudo -E ./install.sh
```

> The detected/forced interface is only picked up at install time. If you
> swap Wi-Fi adapters later, re-run `install.sh` (or edit `WLAN_IFACE=` in
> `/etc/default/hotspot` by hand).

### 3.2 Useful environment variables

All of these are optional; sane defaults are used if omitted.

| Variable | Default | Effect |
|---|---|---|
| `SKIP_NODERED` | `0` | Set to `1` to skip installing Node-RED (e.g. already present) |
| `SKIP_HOTSPOT_INSTALL` | `0` | Set to `1` to skip installing hostapd/dnsmasq/nginx/iptables-persistent |
| `SKIP_DASHBOARD_INSTALL` | `0` | Set to `1` to skip installing python3-venv/python3-pip |
| `NODERED_USER` | `nodered` | System user Node-RED runs as |
| `DASHBOARD_USER` | `pi` | System user the web dashboard runs as |
| `NODERED_PALETTES` | `@flowfuse/node-red-dashboard node-red-node-serialport` | Space-separated npm packages to pre-install into Node-RED. Set to `""` to skip |
| `DASHBOARD_ADMIN_PASSWORD` | *(unset → default `admin`)* | Pre-seed the dashboard admin password |
| `WLAN_IFACE` | *(auto-detected)* | Force a specific Wi-Fi interface for the hotspot |

Example combining a few:

```bash
DASHBOARD_USER=web NODERED_PALETTES="" WLAN_IFACE=wlp2s0 sudo -E ./install.sh
```

## 4. What happens during installation

1. Installs Node.js + Node-RED via the official installer (unless
   `SKIP_NODERED=1` or already present).
2. Creates the `nodered` system user (no login shell, member of `dialout`
   for serial access) and installs the configured Node-RED palettes.
3. Copies `find_arduino.sh`, `setup-hotspot.sh`, and `startup-sequence.sh`
   to `/usr/local/bin/`.
4. Sets up the `lan-dashboard` web app:
   - installs `python3-venv`/`python3-pip`
   - creates the dashboard system user (default `pi`) if missing
   - copies the app files to `/home/<user>/lan-dashboard`
   - creates a Python virtualenv and installs dependencies
   - generates a `.env` file with a random secret key (only if one doesn't
     already exist)
   - grants the dashboard user passwordless `sudo` for exactly two commands:
     shutdown, and restarting the hotspot (needed for the UI's power button
     and Wi-Fi settings)
   - installs `lan-dashboard.service`
5. Detects the Wi-Fi interface (see 3.1) and installs hostapd/dnsmasq/nginx
   (unless `SKIP_HOTSPOT_INSTALL=1`).
6. Writes `/etc/default/startup-sequence` with the chosen `NODERED_USER` and
   `DASHBOARD_USER`.
7. Installs `startup-sequence.service`, the udev rule, and
   `find-arduino@.service`, then reloads udev and systemd and enables
   `startup-sequence.service` (started automatically on every boot).

`lan-dashboard.service` is **not** separately enabled — `startup-sequence.sh`
starts it explicitly, in order, before bringing up the hotspot.

## 6. Boot order

```
udev settle
  → Arduino symlinks (find_arduino.sh -a -s)
    → Node-RED (as $NODERED_USER, waits up to 60s for port 1880)
      → lan-dashboard (systemctl start, waits up to 30s for port 5000)
        → hotspot (setup-hotspot.sh start)
```

The hotspot is started last on purpose: its captive portal points at the
dashboard/Node-RED domains, so both need to already be answering.

## 7. Accessing things afterward
The hotspot has a capture portal setup. Because of this you will get a notification on your device (or in the browser), the notification opens the dashboard automatically. The capture portal works on Windows, MacOS, Linux and IOS. It does not work on Android. Here you'll need to open the link automatically. 

- Dashboard: `http://<device-ip>:5000` (or `http://dashboard.hotspot` once
  connected to the hotspot)
- Node-RED: `http://<device-ip>:1880` (or `http://nodered.hotspot`)
- Hotspot SSID/password: default `Hotspot` / `Password`, changeable from the
  dashboard's Admin mode → Wi-Fi settings
- Dashboard admin password: default `admin` (or whatever
  `DASHBOARD_ADMIN_PASSWORD` was set to), changeable from Admin mode

## 8. Troubleshooting

| Symptom | Likely cause |
|---|---|
| `install.sh` aborts with "No Wi-Fi interface found" | No Wi-Fi adapter present/enabled, or driver not loaded — check `ip a` |
| `install.sh` aborts with "Multiple Wi-Fi interfaces found" | Set `WLAN_IFACE=<name>` explicitly |
| Hotspot fails to start with "Failed to set channel" | Regulatory domain issue — check `COUNTRY_CODE` in `setup-hotspot.sh` |
| `startup-sequence.service` fails at boot but dashboard/Node-RED work | Hotspot step failed (e.g. wrong/missing Wi-Fi interface) — check `journalctl -u startup-sequence.service -e` |
| Dashboard unreachable on port 5000 | Check `systemctl status lan-dashboard.service` and `journalctl -u lan-dashboard.service` |
|E: Could not open lock file /var/lib/apt/lists/lock|run sudo `sudo rm -rf /var/lib/apt/lists/*`|
