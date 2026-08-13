# Pi-Einrichtung
 
Anleitung, um den Raspberry Pi von einer frischen Ubuntu-Installation bis zum
fertig laufenden Hotspot (WLAN + Captive Portal + Dashboard + Node-RED +
Arduino-Erkennung) einzurichten.
 
## Voraussetzungen
 
- Raspberry Pi mit nicht Raspberry Pi OS 
- Internetzugang während der Installation (zum Herunterladen von Paketen,
  Node.js/Node-RED)
- WLAN-Interface, das den AP-Modus unterstützt (Standardname `wlan0` – mit
  `ip a` prüfen, falls dein Adapter anders heißt)
- SSH-Zugriff oder direkter Zugang mit Tastatur/Bildschirm
## 1. Dateien auf den Pi kopieren
 
Das komplette `firmware`-Verzeichnis auf den Pi kopieren, z.B. per `scp`:
 
```bash
scp -r firmware pi@raspberrypi.local:/home/pi/
```
 
Oder das ZIP-Archiv direkt auf dem Pi hochladen und dort entpacken:
 
```bash
unzip firmware.zip
cd firmware
```
 
## 2. install.sh ausführen
 
Das Installationsskript erledigt automatisch **alles auf einmal**: Node.js +
Node-RED installieren, Systembenutzer anlegen, Hotspot-Pakete installieren
(hostapd/dnsmasq/nginx), das Dashboard einrichten (Python-venv, systemd-Unit),
udev-Regel für die Arduino-Erkennung einrichten und die Boot-Startsequenz
aktivieren.
 
```bash
sudo ./install.sh
```
 
Das Skript fragt dabei **nichts interaktiv ab** – SSID, WLAN-Passwort und
Admin-Passwort starten mit Standardwerten (siehe unten) und werden später
über die Weboberfläche geändert.
 
### Optionale Umgebungsvariablen
 
Vor dem Aufruf per `NAME=wert sudo -E ./install.sh` setzbar (das `-E` ist
wichtig, sonst gehen die Variablen beim `sudo`-Wechsel verloren):
 
| Variable | Bedeutung | Standard |
|---|---|---|
| `DASHBOARD_USER` | Systembenutzer, unter dem das Dashboard läuft | `pi` |
| `NODERED_USER` | Systembenutzer, unter dem Node-RED läuft | `nodered` |
| `DASHBOARD_ADMIN_PASSWORD` | Admin-Passwort fürs Dashboard, direkt vorbelegt | `admin` |
| `NODERED_PALETTES` | Node-RED-Paletten, die installiert werden | `@flowfuse/node-red-dashboard node-red-node-serialport` |
| `SKIP_NODERED` | `1` = Node-RED-Installation überspringen (z.B. schon vorhanden) | `0` |
| `SKIP_HOTSPOT_INSTALL` | `1` = hostapd/dnsmasq/nginx nicht installieren | `0` |
| `SKIP_DASHBOARD_INSTALL` | `1` = python3-venv/pip nicht installieren | `0` |
 
Beispiel mit eigenem Admin-Passwort:
 
```bash
DASHBOARD_ADMIN_PASSWORD=meinsicherespasswort sudo -E ./install.sh
```
 
## 3. Installation prüfen
 
```bash
sudo systemctl start startup-sequence.service
systemctl status startup-sequence.service
journalctl -u startup-sequence.service -e
```
 
`startup-sequence.service` startet beim Booten automatisch zuerst das
Dashboard und danach den Hotspot (in dieser Reihenfolge, damit der Hotspot
erst online geht, wenn das Dashboard bereits antwortet).
 
## 4. Hotspot manuell steuern
 
Für gezieltes Starten/Stoppen/Neustarten, unabhängig von der
Boot-Startsequenz:
 
```bash
sudo setup-hotspot.sh start
sudo setup-hotspot.sh stop
sudo setup-hotspot.sh restart
```
 
## 5. Verbindung testen
 
Mit einem zweiten Gerät (Handy/Laptop) mit dem WLAN verbinden:
 
- **SSID:** `Hotspot` (Standardwert, änderbar im Admin-Modus des Dashboards)
- **Passwort:** `Password` (Standardwert, änderbar im Admin-Modus)
Nach dem Verbinden sollte sich automatisch die Portalseite öffnen
(Captive-Portal-Erkennung). Manuell erreichbar sind:
 
- Dashboard: `http://dashboard.hotspot`
- Node-RED: `http://nodered.hotspot`
## 6. Admin-Zugang zum Dashboard
 
- Auf den Button **„Admin"** oben rechts klicken.
- Standard-Passwort: `admin` (bzw. der bei der Installation über
  `DASHBOARD_ADMIN_PASSWORD` gesetzte Wert).
- Im Admin-Modus lassen sich SSID/WLAN-Passwort, Admin-Passwort,
  Überschriften, Logo, Farbschema und die Schaltflächen ändern – alles ohne
  erneutes Ausführen von `install.sh`.
## 7. Arduino anschließen
 
Sobald ein Arduino (oder Clone) per USB angesteckt wird, erkennt die
udev-Regel (`99-arduino.rules`) das Gerät automatisch und startet
`find-arduino@<Port>.service`, welches `find_arduino.sh` aufruft. Gefundene
Boards bekommen zusätzlich einen stabilen Symlink unter `/dev/arduino/<ID>`.
 
Prüfen, welche Boards aktuell erkannt sind:
 
```bash
ls -l /dev/ttyACM* /dev/ttyUSB* 2>/dev/null
ls -l /dev/arduino/ 2>/dev/null
```
 
## 8. Node-RED
 
Node-RED läuft als eigener Systembenutzer (`nodered`, Standardwert) und ist
über `http://nodered.hotspot` erreichbar. Die installierten Paletten stehen
danach direkt im Editor zur Verfügung; eigene Flows werden in
`/home/nodered/.node-red/flows.json` gespeichert.
 
## Deinstallation
 
Um alle Änderungen wieder rückgängig zu machen:
 
```bash
sudo ./uninstall.sh
```
 
Siehe Kommentar-Kopf in `uninstall.sh` für Optionen (`KEEP_USERS`,
`KEEP_PACKAGES`, abweichende `DASHBOARD_USER`/`NODERED_USER`).
 
## Typische Stolpersteine
 
- **Falscher WLAN-Interface-Name:** Falls `wlan0` nicht existiert, mit `ip a`
  den richtigen Namen ermitteln und in `setup-hotspot.sh`
  (`WLAN_IFACE="wlan0"`) anpassen.
- **Falsches Land/keine 2,4-GHz-Kanäle möglich:** `COUNTRY_CODE` in
  `setup-hotspot.sh` prüfen (Standard `DE`).
- **Port 80 schon belegt:** `sudo ss -tlnp | grep :80` prüfen, bevor der
  Hotspot gestartet wird.
- **Altes Admin-Passwort trotz Neuinstallation:** `install.sh` überschreibt
  eine bereits vorhandene `admin_config.json`/`hotspot_config.json` im
  Zielverzeichnis **nicht** – bei Bedarf vorher manuell löschen
  (`/home/<DASHBOARD_USER>/lan-dashboard/admin_config.json`).
