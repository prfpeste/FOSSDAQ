import json
import os
import uuid
from functools import wraps

from flask import Flask, jsonify, request, render_template, session, url_for
from werkzeug.security import generate_password_hash, check_password_hash
from werkzeug.utils import secure_filename

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_FILE = os.path.join(BASE_DIR, "buttons.json")
ADMIN_CONFIG_FILE = os.path.join(BASE_DIR, "admin_config.json")
SETTINGS_FILE = os.path.join(BASE_DIR, "settings.json")
UPLOAD_DIR = os.path.join(BASE_DIR, "static", "uploads")
ALLOWED_LOGO_EXTENSIONS = {"png", "jpg", "jpeg", "gif", "webp", "svg"}
MAX_LOGO_SIZE = 3 * 1024 * 1024  # 3 MB

os.makedirs(UPLOAD_DIR, exist_ok=True)

DEFAULT_SETTINGS = {
    "eyebrow": "LOKALES NETZWERK",
    "title": "Kontrolltafel",
    "theme": "dark",
    "logo_filename": None,
}

app = Flask(__name__)
# WICHTIG: Für den Produktivbetrieb per Umgebungsvariable SECRET_KEY setzen
# (siehe README.md), sonst funktioniert der Login nach jedem Neustart neu,
# ist aber unsicher vorhersehbar.
app.secret_key = os.environ.get("SECRET_KEY", "bitte-aendern-vor-produktivbetrieb")

# Anfangs-Admin-Passwort per Umgebungsvariable setzen (siehe README.md).
# Sobald das Passwort einmal über die Weboberfläche geändert wurde, wird es
# stattdessen (gehasht) in admin_config.json gespeichert und hat Vorrang.
ADMIN_PASSWORD = os.environ.get("ADMIN_PASSWORD", "admin")


def load_admin_password_hash():
    """Gibt den gespeicherten Passwort-Hash zurück, falls vorhanden."""
    if not os.path.exists(ADMIN_CONFIG_FILE):
        return None
    with open(ADMIN_CONFIG_FILE, "r", encoding="utf-8") as f:
        data = json.load(f)
    return data.get("password_hash")


def save_admin_password(new_password):
    with open(ADMIN_CONFIG_FILE, "w", encoding="utf-8") as f:
        json.dump({"password_hash": generate_password_hash(new_password)}, f)


def verify_admin_password(password):
    stored_hash = load_admin_password_hash()
    if stored_hash:
        return check_password_hash(stored_hash, password)
    # Solange das Passwort noch nie über die Weboberfläche geändert wurde,
    # gilt weiterhin das Passwort aus der Umgebungsvariable (Klartext-Vergleich).
    return password == ADMIN_PASSWORD


def load_buttons():
    if not os.path.exists(DATA_FILE):
        return []
    with open(DATA_FILE, "r", encoding="utf-8") as f:
        return json.load(f)


def save_buttons(buttons):
    with open(DATA_FILE, "w", encoding="utf-8") as f:
        json.dump(buttons, f, ensure_ascii=False, indent=2)


def load_settings():
    """Gibt die gespeicherten Einstellungen zurück (Überschriften, Theme, Logo)."""
    settings = dict(DEFAULT_SETTINGS)
    if os.path.exists(SETTINGS_FILE):
        with open(SETTINGS_FILE, "r", encoding="utf-8") as f:
            try:
                stored = json.load(f)
            except json.JSONDecodeError:
                stored = {}
        settings.update({k: v for k, v in stored.items() if k in DEFAULT_SETTINGS})
    return settings


def save_settings(settings):
    with open(SETTINGS_FILE, "w", encoding="utf-8") as f:
        json.dump(settings, f, ensure_ascii=False, indent=2)


def allowed_logo_file(filename):
    return (
        "." in filename
        and filename.rsplit(".", 1)[1].lower() in ALLOWED_LOGO_EXTENSIONS
    )


def admin_required(fn):
    @wraps(fn)
    def wrapper(*args, **kwargs):
        if not session.get("is_admin"):
            return jsonify({"error": "Nicht angemeldet"}), 401
        return fn(*args, **kwargs)
    return wrapper


@app.route("/")
def index():
    settings = load_settings()
    logo_url = None
    if settings.get("logo_filename"):
        logo_path = os.path.join(UPLOAD_DIR, settings["logo_filename"])
        if os.path.exists(logo_path):
            logo_url = url_for("static", filename=f"uploads/{settings['logo_filename']}")
    return render_template("index.html", settings=settings, logo_url=logo_url)


@app.route("/api/status")
def status():
    return jsonify({"is_admin": bool(session.get("is_admin"))})


@app.route("/api/settings", methods=["GET"])
def get_settings():
    settings = load_settings()
    logo_url = None
    if settings.get("logo_filename"):
        logo_path = os.path.join(UPLOAD_DIR, settings["logo_filename"])
        if os.path.exists(logo_path):
            logo_url = url_for("static", filename=f"uploads/{settings['logo_filename']}")
    return jsonify({
        "eyebrow": settings["eyebrow"],
        "title": settings["title"],
        "theme": settings["theme"],
        "logo_url": logo_url,
    })


@app.route("/api/settings", methods=["PUT"])
@admin_required
def update_settings():
    data = request.get_json(silent=True) or {}
    settings = load_settings()

    if "eyebrow" in data:
        eyebrow = (data["eyebrow"] or "").strip()
        if eyebrow:
            settings["eyebrow"] = eyebrow[:60]
    if "title" in data:
        title = (data["title"] or "").strip()
        if title:
            settings["title"] = title[:60]
    if "theme" in data:
        theme = data["theme"]
        if theme in ("dark", "light"):
            settings["theme"] = theme

    save_settings(settings)
    return jsonify({"ok": True})


@app.route("/api/settings/logo", methods=["POST"])
@admin_required
def upload_logo():
    if "logo" not in request.files:
        return jsonify({"error": "Keine Datei erhalten"}), 400
    file = request.files["logo"]
    if not file or file.filename == "":
        return jsonify({"error": "Keine Datei ausgewählt"}), 400
    if not allowed_logo_file(file.filename):
        return jsonify({"error": "Nur Bilddateien erlaubt (png, jpg, gif, webp, svg)"}), 400

    file.seek(0, os.SEEK_END)
    size = file.tell()
    file.seek(0)
    if size > MAX_LOGO_SIZE:
        return jsonify({"error": "Datei zu groß (max. 3 MB)"}), 400

    settings = load_settings()

    # Alte Datei entfernen, falls vorhanden
    if settings.get("logo_filename"):
        old_path = os.path.join(UPLOAD_DIR, settings["logo_filename"])
        if os.path.exists(old_path):
            os.remove(old_path)

    ext = secure_filename(file.filename).rsplit(".", 1)[1].lower()
    new_filename = f"logo-{uuid.uuid4().hex}.{ext}"
    file.save(os.path.join(UPLOAD_DIR, new_filename))

    settings["logo_filename"] = new_filename
    save_settings(settings)

    logo_url = url_for("static", filename=f"uploads/{new_filename}")
    return jsonify({"ok": True, "logo_url": logo_url})


@app.route("/api/settings/logo", methods=["DELETE"])
@admin_required
def delete_logo():
    settings = load_settings()
    if settings.get("logo_filename"):
        old_path = os.path.join(UPLOAD_DIR, settings["logo_filename"])
        if os.path.exists(old_path):
            os.remove(old_path)
        settings["logo_filename"] = None
        save_settings(settings)
    return jsonify({"ok": True})


@app.route("/api/login", methods=["POST"])
def login():
    data = request.get_json(silent=True) or {}
    password = data.get("password", "")
    if password and verify_admin_password(password):
        session["is_admin"] = True
        session.permanent = True
        return jsonify({"ok": True})
    return jsonify({"ok": False, "error": "Falsches Passwort"}), 401


@app.route("/api/logout", methods=["POST"])
def logout():
    session.pop("is_admin", None)
    return jsonify({"ok": True})


@app.route("/api/admin/password", methods=["PUT"])
@admin_required
def change_admin_password():
    data = request.get_json(silent=True) or {}
    current_password = data.get("current_password", "")
    new_password = data.get("new_password", "")

    if not verify_admin_password(current_password):
        return jsonify({"error": "Aktuelles Passwort ist falsch"}), 401
    if not new_password or len(new_password) < 4:
        return jsonify({"error": "Neues Passwort muss mindestens 4 Zeichen haben"}), 400

    save_admin_password(new_password)
    return jsonify({"ok": True})


@app.route("/api/buttons", methods=["GET"])
def get_buttons():
    buttons = load_buttons()
    if not session.get("is_admin"):
        buttons = [b for b in buttons if b.get("visible", True)]
    buttons.sort(key=lambda b: b.get("order", 0))
    return jsonify(buttons)


@app.route("/api/buttons", methods=["POST"])
@admin_required
def create_button():
    data = request.get_json(silent=True) or {}
    label = (data.get("label") or "").strip()
    url = (data.get("url") or "").strip()
    if not label or not url:
        return jsonify({"error": "Anzeigename und Link sind erforderlich"}), 400

    buttons = load_buttons()
    new_button = {
        "id": str(uuid.uuid4()),
        "label": label,
        "url": url,
        "visible": True,
        "order": len(buttons),
    }
    buttons.append(new_button)
    save_buttons(buttons)
    return jsonify(new_button), 201


@app.route("/api/buttons/<button_id>", methods=["PUT"])
@admin_required
def update_button(button_id):
    data = request.get_json(silent=True) or {}
    buttons = load_buttons()
    for b in buttons:
        if b["id"] == button_id:
            if "label" in data:
                label = (data["label"] or "").strip()
                if label:
                    b["label"] = label
            if "url" in data:
                url = (data["url"] or "").strip()
                if url:
                    b["url"] = url
            if "visible" in data:
                b["visible"] = bool(data["visible"])
            save_buttons(buttons)
            return jsonify(b)
    return jsonify({"error": "Nicht gefunden"}), 404


@app.route("/api/buttons/<button_id>", methods=["DELETE"])
@admin_required
def delete_button(button_id):
    buttons = load_buttons()
    new_buttons = [b for b in buttons if b["id"] != button_id]
    if len(new_buttons) == len(buttons):
        return jsonify({"error": "Nicht gefunden"}), 404
    save_buttons(new_buttons)
    return jsonify({"ok": True})


if __name__ == "__main__":
    # host=0.0.0.0 macht die Seite im lokalen Netzwerk erreichbar
    app.run(host="0.0.0.0", port=5000, debug=False)
