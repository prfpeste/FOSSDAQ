# LAN Kontrolltafel

Kleine Weboberfläche für den Raspberry Pi mit Schaltflächen, die zu anderen
lokalen Webseiten weiterleiten. Über den Admin-Modus (Passwort-geschützt)
lassen sich Schaltflächen anlegen, bearbeiten, löschen und ein-/ausblenden.

## 1. Dateien auf den Pi kopieren

```bash
scp -r lan-dashboard pi@raspberrypi.local:/home/pi/
```

Oder direkt auf dem Pi entpacken, falls du das Zip dort hochgeladen hast.

## 2. Python-Umgebung einrichten

Auf dem Pi:

```bash
cd /home/pi/lan-dashboard
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

## 3. Passwort und Secret Key setzen

Datei `.env` anlegen (liegt NICHT im Repo, da sie Geheimnisse enthält):

```bash
cat > /home/pi/lan-dashboard/.env << 'EOF'
ADMIN_PASSWORD=dein-sicheres-passwort
SECRET_KEY=eine-lange-zufaellige-zeichenkette
EOF
```

Einen zufälligen Secret Key erzeugen:

```bash
python3 -c "import secrets; print(secrets.token_hex(32))"
```

## 4. Kurzer Test (ohne systemd)

```bash
set -a && source .env && set +a
venv/bin/python app.py
```

Dann im Browser eines Geräts im gleichen Netzwerk aufrufen:
`http://raspberrypi.local:5000` (oder `http://<IP-des-Pi>:5000`).
Mit `Strg+C` wieder beenden.

## 5. Als Dienst einrichten (startet automatisch beim Booten)

```bash
sudo cp lan-dashboard.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now lan-dashboard.service
```

Status prüfen:

```bash
systemctl status lan-dashboard.service
journalctl -u lan-dashboard.service -f
```

## 6. Optional: Port 80 statt 5000

Standardmäßig läuft die Seite auf Port 5000. Falls sie im Netzwerk unter
`http://raspberrypi.local` (ohne Portangabe) erreichbar sein soll, entweder:

- den Dienst direkt auf Port 80 binden (`-b 0.0.0.0:80` in der .service-Datei;
  dafür braucht gunicorn dann Root-Rechte oder die Capability
  `CAP_NET_BIND_SERVICE`), oder
- **nginx** als Reverse-Proxy davor schalten, der Port 80 nach 5000
  weiterleitet.

Falls auf dem Pi bereits ein Hotspot mit Captive Portal läuft (eigener
Webserver auf Port 80), auf jeden Fall vorher prüfen, ob der Port schon belegt
ist (`sudo ss -tlnp | grep :80`), um Konflikte zu vermeiden.

## Daten & Sicherung

Die Schaltflächen werden in `buttons.json` gespeichert. Sobald das
Admin-Passwort über die Weboberfläche geändert wurde, legt die App zusätzlich
`admin_config.json` an (enthält nur den gehashten Passwort-Wert, kein
Klartext) — dieses Passwort hat dann Vorrang vor `ADMIN_PASSWORD` aus der
`.env`-Datei. Überschriften, das gewählte Farbschema (hell/dunkel) und das
hochgeladene Bild werden in `settings.json` bzw. `static/uploads/`
gespeichert und bleiben nach einem Neustart des Pi erhalten. Für ein Backup
reicht es, `buttons.json`, `settings.json`, den Ordner `static/uploads/` und
ggf. `admin_config.json` zu sichern.

## Kopfzeile im Admin-Modus anpassen

Im Admin-Modus sind die beiden Überschriften ("LOKALES NETZWERK" und
"Kontrolltafel") direkt anklickbar und lassen sich bearbeiten — Änderungen
werden beim Verlassen des Feldes (oder mit Enter) automatisch gespeichert.
Links davon lässt sich über das Bild-Symbol ein eigenes Logo hochladen
(PNG/JPG/GIF/WEBP/SVG, max. 3 MB); es ist danach für alle Besucher sichtbar,
auch außerhalb des Admin-Modus. Über das ✕-Symbol lässt es sich wieder
entfernen.

## Hell-/Dunkelmodus

Rechts oben erscheint im Admin-Modus ein Symbol (🌙/☀) zum Umschalten
zwischen Dunkel- und Hellmodus. Die Wahl gilt für alle Besucher der Seite
(nicht nur für den Admin) und bleibt nach einem Neustart erhalten.

## Admin-Passwort in der Oberfläche ändern

Im Admin-Modus erscheint links neben dem Admin-Button ein Schlüssel-Symbol
(🔑). Dort lässt sich das aktuelle Passwort eingeben und ein neues Passwort
(mind. 4 Zeichen) zweimal bestätigen.

## Admin-Modus benutzen

- Auf den "Admin"-Button oben rechts klicken und Passwort eingeben.
- Im Admin-Modus erscheinen an jeder Kachel drei Symbole: Auge (ein-/
  ausblenden), Stift (bearbeiten), Kreuz (löschen) — sowie unten eine Kachel
  "Neue Schaltfläche".
- Ausgeblendete Schaltflächen sind für normale Besucher unsichtbar und werden
  nur im Admin-Modus (leicht transparent) angezeigt.
