import json
import os
import subprocess
import uuid
from functools import wraps

from flask import Flask, jsonify, request, render_template, session, url_for
from werkzeug.security import generate_password_hash, check_password_hash
from werkzeug.utils import secure_filename

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_FILE = os.path.join(BASE_DIR, "buttons.json")
ADMIN_CONFIG_FILE = os.path.join(BASE_DIR, "admin_config.json")
SETTINGS_FILE = os.path.join(BASE_DIR, "settings.json")
HOTSPOT_CONFIG_FILE = os.path.join(BASE_DIR, "hotspot_config.json")
UPLOAD_DIR = os.path.join(BASE_DIR, "static", "uploads")
ALLOWED_LOGO_EXTENSIONS = {"png", "jpg", "jpeg", "gif", "webp", "svg"}
MAX_LOGO_SIZE = 3 * 1024 * 1024  # 3 MB

# Link to the Git repository of this project, displayed at the bottom center in the footer.
# Adjust here if needed.
GIT_REPO_URL = os.environ.get("GIT_REPO_URL", "https://github.com/prfpeste/FOSSDAQ")

os.makedirs(UPLOAD_DIR, exist_ok=True)

DEFAULT_SETTINGS = {
    "eyebrow": "Institution",
    "title": "Title",
    "theme": "light",
    "logo_filename": None,
}

# Default values for the hotspot. Used during the very first start (if no
# hotspot_config.json exists yet) and can be changed afterward via the
# web interface (Admin mode) - see /api/settings/hotspot.
DEFAULT_HOTSPOT_CONFIG = {
    "ssid": "Hotspot",
    "password": "Password",
}

app = Flask(__name__)
# IMPORTANT: For production, set SECRET_KEY via environment variable
# (see README.md), otherwise the login will reset after each restart,
# but is insecure and predictable.
app.secret_key = os.environ.get("SECRET_KEY", "please-change-before-production")

# Initial admin password via environment variable (see README.md).
# Once the password is changed via the web interface, it is stored
# (hashed) in admin_config.json instead and takes precedence.
ADMIN_PASSWORD = os.environ.get("ADMIN_PASSWORD", "admin")

def load_admin_password_hash():
    """Returns the stored password hash if available."""
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
    # As long as the password has never been changed via the web interface,
    # the password from the environment variable (plaintext comparison) still applies.
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
    """Returns the saved settings (headings, theme, logo)."""
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

def load_hotspot_config():
    config = dict(DEFAULT_HOTSPOT_CONFIG)
    if os.path.exists(HOTSPOT_CONFIG_FILE):
        with open(HOTSPOT_CONFIG_FILE, "r", encoding="utf-8") as f:
            try:
                stored = json.load(f)
            except json.JSONDecodeError:
                stored = {}
        config.update({k: v for k, v in stored.items() if k in DEFAULT_HOTSPOT_CONFIG})
    return config

def save_hotspot_config(config):
    with open(HOTSPOT_CONFIG_FILE, "w", encoding="utf-8") as f:
        json.dump(config, f, ensure_ascii=False, indent=2)

def allowed_logo_file(filename):
    return (
        "." in filename
        and filename.rsplit(".", 1)[1].lower() in ALLOWED_LOGO_EXTENSIONS
    )

def admin_required(fn):
    @wraps(fn)
    def wrapper(*args, **kwargs):
        if not session.get("is_admin"):
            return jsonify({"error": "Not logged in"}), 401
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
    return render_template(
        "index.html", settings=settings, logo_url=logo_url, git_repo_url=GIT_REPO_URL
    )

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
        return jsonify({"error": "No file received"}), 400
    file = request.files["logo"]
    if not file or file.filename == "":
        return jsonify({"error": "No file selected"}), 400
    if not allowed_logo_file(file.filename):
        return jsonify({"error": "Only image files allowed (png, jpg, gif, webp, svg)"}), 400

    file.seek(0, os.SEEK_END)
    size = file.tell()
    file.seek(0)
    if size > MAX_LOGO_SIZE:
        return jsonify({"error": "File too large (max. 3 MB)"}), 400

    settings = load_settings()

    # Remove old file if present
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
    return jsonify({"ok": False, "error": "Wrong password"}), 401

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
        return jsonify({"error": "Current password is incorrect"}), 401
    if not new_password or len(new_password) < 4:
        return jsonify({"error": "New password must be at least 4 characters"}), 400

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
        return jsonify({"error": "Display name and link are required"}), 400

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
    return jsonify({"error": "Not found"}), 404

@app.route("/api/buttons/<button_id>", methods=["DELETE"])
@admin_required
def delete_button(button_id):
    buttons = load_buttons()
    new_buttons = [b for b in buttons if b["id"] != button_id]
    if len(new_buttons) == len(buttons):
        return jsonify({"error": "Not found"}), 404
    save_buttons(new_buttons)
    return jsonify({"ok": True})

@app.route("/api/settings/hotspot", methods=["GET"])
@admin_required
def get_hotspot_settings():
    config = load_hotspot_config()
    return jsonify({"ssid": config["ssid"]})

@app.route("/api/settings/hotspot", methods=["PUT"])
@admin_required
def update_hotspot_settings():
    data = request.get_json(silent=True) or {}
    config = load_hotspot_config()

    ssid = (data.get("ssid") or "").strip()
    if ssid:
        config["ssid"] = ssid[:32]

    password = data.get("password")
    if password:
        if len(password) < 8:
            return jsonify({"error": "Wi-Fi password must be at least 8 characters"}), 400
        config["password"] = password

    # Intentionally NOT applied immediately (no hotspot restart here) -
    # the hotspot continues to run with the old credentials until the user
    # triggers a PC restart via the restart popup in the frontend. On boot,
    # setup-hotspot.sh reads the file again (see startup-sequence.sh).
    save_hotspot_config(config)
    return jsonify({"ok": True, "ssid": config["ssid"], "restart_required": True})

@app.route("/api/system/shutdown", methods=["POST"])
def system_shutdown():
    # Intentionally WITHOUT admin login: The on/off button should also be
    # usable in standard mode for everyone (see README). Requires a
    # matching NOPASSWD entry in /etc/sudoers.d/lan-dashboard, otherwise
    # the command will fail.
    try:
        subprocess.Popen(["sudo", "/sbin/shutdown", "-h", "now"])
    except Exception as e:
        return jsonify({"error": f"Shutdown failed: {e}"}), 500
    return jsonify({"ok": True})

@app.route("/api/system/restart", methods=["POST"])
def system_restart():
    try:
        subprocess.Popen(["sudo", "/sbin/shutdown", "-r", "now"])
    except Exception as e:
        return jsonify({"error": f"Restart failed: {e}"}), 500
    return jsonify({"ok": True})

if __name__ == "__main__":
    # host=0.0.0.0 makes the page accessible in the local network
    app.run(host="0.0.0.0", port=5000, debug=False)
