const grid = document.getElementById("grid");
const emptyHint = document.getElementById("emptyHint");
const tileTemplate = document.getElementById("tileTemplate");
const addTileBtn = document.getElementById("addTileBtn");
const adminToggle = document.getElementById("adminToggle");

const loginBackdrop = document.getElementById("loginBackdrop");
const loginForm = document.getElementById("loginForm");
const loginPassword = document.getElementById("loginPassword");
const loginError = document.getElementById("loginError");
const loginCancel = document.getElementById("loginCancel");

const editBackdrop = document.getElementById("editBackdrop");
const editForm = document.getElementById("editForm");
const editTitle = document.getElementById("editTitle");
const editLabel = document.getElementById("editLabel");
const editUrl = document.getElementById("editUrl");
const editError = document.getElementById("editError");
const editCancel = document.getElementById("editCancel");

const adminPasswordBtn = document.getElementById("adminPasswordBtn");
const passwordBackdrop = document.getElementById("passwordBackdrop");
const passwordForm = document.getElementById("passwordForm");
const currentPassword = document.getElementById("currentPassword");
const newPassword = document.getElementById("newPassword");
const newPassword2 = document.getElementById("newPassword2");
const passwordError = document.getElementById("passwordError");
const passwordCancel = document.getElementById("passwordCancel");

const powerBtn = document.getElementById("powerBtn");
const powerBackdrop = document.getElementById("powerBackdrop");
const powerCancel = document.getElementById("powerCancel");
const powerError = document.getElementById("powerError");
const powerRestartBtn = document.getElementById("powerRestartBtn");
const powerShutdownBtn = document.getElementById("powerShutdownBtn");

const hotspotSettingsBtn = document.getElementById("hotspotSettingsBtn");
const hotspotBackdrop = document.getElementById("hotspotBackdrop");
const hotspotForm = document.getElementById("hotspotForm");
const hotspotSsid = document.getElementById("hotspotSsid");
const hotspotPassword = document.getElementById("hotspotPassword");
const hotspotPassword2 = document.getElementById("hotspotPassword2");
const hotspotError = document.getElementById("hotspotError");
const hotspotCancel = document.getElementById("hotspotCancel");

const hotspotRestartBackdrop = document.getElementById("hotspotRestartBackdrop");
const hotspotRestartError = document.getElementById("hotspotRestartError");
const hotspotRestartLater = document.getElementById("hotspotRestartLater");
const hotspotRestartNow = document.getElementById("hotspotRestartNow");

const themeToggle = document.getElementById("themeToggle");
const topbarLogo = document.getElementById("topbarLogo");
const logoEditBtn = document.getElementById("logoEditBtn");
const logoRemoveBtn = document.getElementById("logoRemoveBtn");
const logoFileInput = document.getElementById("logoFileInput");
const topbarEyebrow = document.getElementById("topbarEyebrow");
const topbarTitle = document.getElementById("topbarTitle");

let isAdmin = false;
let editingId = null; // null = new button is being created
let currentTheme = document.documentElement.getAttribute("data-theme") || "dark";

async function api(path, options = {}) {
  const res = await fetch(path, {
    headers: { "Content-Type": "application/json" },
    ...options,
  });
  let data = null;
  try {
    data = await res.json();
  } catch (e) {
    data = null;
  }
  if (!res.ok) {
    const message = (data && data.error) || "Unknown error";
    throw new Error(message);
  }
  return data;
}

function renderTiles(buttons) {
  grid.innerHTML = "";
  emptyHint.hidden = buttons.length > 0 || isAdmin;

  buttons.forEach((button) => {
    const node = tileTemplate.content.firstElementChild.cloneNode(true);
    node.dataset.id = button.id;
    if (!button.visible) node.classList.add("tile--hidden");

    const link = node.querySelector(".tile__link");
    link.href = button.url;
    node.querySelector(".tile__label").textContent = button.label;

    node.querySelector(".tile__toggle-visibility").addEventListener("click", () => {
      toggleVisibility(button);
    });
    node.querySelector(".tile__edit").addEventListener("click", () => {
      openEditModal(button);
    });
    node.querySelector(".tile__delete").addEventListener("click", () => {
      deleteButton(button);
    });

    grid.appendChild(node);
  });
}

async function loadButtons() {
  const buttons = await api("/api/buttons");
  renderTiles(buttons);
}

async function toggleVisibility(button) {
  await api(`/api/buttons/${button.id}`, {
    method: "PUT",
    body: JSON.stringify({ visible: !button.visible }),
  });
  loadButtons();
}

async function deleteButton(button) {
  if (!confirm(`Really delete "${button.label}"?`)) return;
  await api(`/api/buttons/${button.id}`, { method: "DELETE" });
  loadButtons();
}

function openEditModal(button) {
  editingId = button ? button.id : null;
  editTitle.textContent = button ? "Edit Button" : "New Button";
  editLabel.value = button ? button.label : "";
  editUrl.value = button ? button.url : "";
  editError.hidden = true;
  editBackdrop.hidden = false;
  editLabel.focus();
}

function closeEditModal() {
  editBackdrop.hidden = true;
  editForm.reset();
}

editForm.addEventListener("submit", async (e) => {
  e.preventDefault();
  const payload = { label: editLabel.value.trim(), url: editUrl.value.trim() };
  try {
    if (editingId) {
      await api(`/api/buttons/${editingId}`, {
        method: "PUT",
        body: JSON.stringify(payload),
      });
    } else {
      await api("/api/buttons", {
        method: "POST",
        body: JSON.stringify(payload),
      });
    }
    closeEditModal();
    loadButtons();
  } catch (err) {
    editError.textContent = err.message;
    editError.hidden = false;
  }
});

editCancel.addEventListener("click", closeEditModal);
addTileBtn.addEventListener("click", () => openEditModal(null));

function applyTheme(theme) {
  currentTheme = theme === "light" ? "light" : "dark";
  document.documentElement.setAttribute("data-theme", currentTheme);
  themeToggle.textContent = currentTheme === "light" ? "☀" : "🌙";
}

function applyLogo(logoUrl) {
  if (logoUrl) {
    topbarLogo.src = logoUrl;
    topbarLogo.hidden = false;
    logoRemoveBtn.hidden = !isAdmin;
  } else {
    topbarLogo.removeAttribute("src");
    topbarLogo.hidden = true;
    logoRemoveBtn.hidden = true;
  }
}

async function loadSettings() {
  const settings = await api("/api/settings");
  applyTheme(settings.theme);
  applyLogo(settings.logo_url);
  if (document.activeElement !== topbarEyebrow) topbarEyebrow.textContent = settings.eyebrow;
  if (document.activeElement !== topbarTitle) topbarTitle.textContent = settings.title;
  document.title = settings.title;
}

async function saveHeadingEdit(field, el, originalValue) {
  const value = el.textContent.trim();
  if (value === originalValue) return;
  try {
    await api("/api/settings", {
      method: "PUT",
      body: JSON.stringify({ [field]: value }),
    });
    if (field === "title") document.title = value;
  } catch (err) {
    el.textContent = originalValue;
    alert(err.message);
  }
}

[topbarEyebrow, topbarTitle].forEach((el) => {
  const field = el.dataset.editable;
  let originalValue = el.textContent;
  el.addEventListener("focus", () => {
    if (!isAdmin) return;
    originalValue = el.textContent;
  });
  el.addEventListener("blur", () => {
    if (!isAdmin) return;
    saveHeadingEdit(field, el, originalValue);
  });
  el.addEventListener("keydown", (e) => {
    if (!isAdmin) return;
    if (e.key === "Enter") {
      e.preventDefault();
      el.blur();
    }
    if (e.key === "Escape") {
      el.textContent = originalValue;
      el.blur();
    }
  });
});

themeToggle.addEventListener("click", async () => {
  if (!isAdmin) return;
  const nextTheme = currentTheme === "light" ? "dark" : "light";
  applyTheme(nextTheme);
  try {
    await api("/api/settings", {
      method: "PUT",
      body: JSON.stringify({ theme: nextTheme }),
    });
  } catch (err) {
    alert(err.message);
  }
});

logoEditBtn.addEventListener("click", () => {
  if (!isAdmin) return;
  logoFileInput.click();
});

logoFileInput.addEventListener("change", async () => {
  const file = logoFileInput.files[0];
  if (!file) return;
  const formData = new FormData();
  formData.append("logo", file);
  try {
    const res = await fetch("/api/settings/logo", { method: "POST", body: formData });
    const data = await res.json();
    if (!res.ok) throw new Error(data.error || "Upload failed");
    applyLogo(data.logo_url);
  } catch (err) {
    alert(err.message);
  } finally {
    logoFileInput.value = "";
  }
});

logoRemoveBtn.addEventListener("click", async () => {
  if (!isAdmin) return;
  if (!confirm("Really remove the image?")) return;
  try {
    await api("/api/settings/logo", { method: "DELETE" });
    applyLogo(null);
  } catch (err) {
    alert(err.message);
  }
});

async function refreshAdminState() {
  const status = await api("/api/status");
  isAdmin = status.is_admin;
  document.body.classList.toggle("is-admin", isAdmin);
  adminToggle.classList.toggle("is-active", isAdmin);
  adminToggle.querySelector(".admin-toggle__text").textContent = isAdmin ? "Logged in" : "Admin";
  adminPasswordBtn.hidden = !isAdmin;
  hotspotSettingsBtn.hidden = !isAdmin;
  themeToggle.hidden = !isAdmin;
  topbarEyebrow.contentEditable = isAdmin ? "true" : "false";
  topbarTitle.contentEditable = isAdmin ? "true" : "false";
  logoEditBtn.hidden = !isAdmin;
  logoRemoveBtn.hidden = !isAdmin || topbarLogo.hidden;
}

adminToggle.addEventListener("click", async () => {
  if (isAdmin) {
    await api("/api/logout", { method: "POST" });
    await refreshAdminState();
    loadButtons();
  } else {
    loginError.hidden = true;
    loginBackdrop.hidden = false;
    loginPassword.value = "";
    loginPassword.focus();
  }
});

loginCancel.addEventListener("click", () => {
  loginBackdrop.hidden = true;
});

loginForm.addEventListener("submit", async (e) => {
  e.preventDefault();
  try {
    await api("/api/login", {
      method: "POST",
      body: JSON.stringify({ password: loginPassword.value }),
    });
    loginBackdrop.hidden = true;
    await refreshAdminState();
    loadButtons();
  } catch (err) {
    loginError.textContent = err.message;
    loginError.hidden = false;
  }
});

adminPasswordBtn.addEventListener("click", () => {
  passwordForm.reset();
  passwordError.hidden = true;
  passwordBackdrop.hidden = false;
  currentPassword.focus();
});

passwordCancel.addEventListener("click", () => {
  passwordBackdrop.hidden = true;
});

passwordForm.addEventListener("submit", async (e) => {
  e.preventDefault();
  if (newPassword.value !== newPassword2.value) {
    passwordError.textContent = "The new passwords do not match";
    passwordError.hidden = false;
    return;
  }
  try {
    await api("/api/admin/password", {
      method: "PUT",
      body: JSON.stringify({
        current_password: currentPassword.value,
        new_password: newPassword.value,
      }),
    });
    passwordBackdrop.hidden = true;
  } catch (err) {
    passwordError.textContent = err.message;
    passwordError.hidden = false;
  }
});

// Shutdown/restart PC - intentionally usable WITHOUT admin login (standard mode).
powerBtn.addEventListener("click", () => {
  powerError.hidden = true;
  powerBackdrop.hidden = false;
});

powerCancel.addEventListener("click", () => {
  powerBackdrop.hidden = true;
});

async function triggerPower(action, label) {
  if (!confirm(`Really ${label} the PC now?`)) return;
  try {
    await api(`/api/system/${action}`, { method: "POST" });
    powerBackdrop.hidden = true;
  } catch (err) {
    powerError.textContent = err.message;
    powerError.hidden = false;
  }
}

powerShutdownBtn.addEventListener("click", () => triggerPower("shutdown", "shut down"));
powerRestartBtn.addEventListener("click", () => triggerPower("restart", "restart"));

// Wi-Fi settings (admin mode only)
hotspotSettingsBtn.addEventListener("click", async () => {
  hotspotError.hidden = true;
  hotspotForm.reset();
  try {
    const config = await api("/api/settings/hotspot");
    hotspotSsid.value = config.ssid;
  } catch (err) {
    hotspotSsid.value = "";
  }
  hotspotBackdrop.hidden = false;
});

hotspotCancel.addEventListener("click", () => {
  hotspotBackdrop.hidden = true;
});

hotspotForm.addEventListener("submit", async (e) => {
  e.preventDefault();

  if (hotspotPassword.value || hotspotPassword2.value) {
    if (hotspotPassword.value !== hotspotPassword2.value) {
      hotspotError.textContent = "The entered Wi-Fi passwords do not match";
      hotspotError.hidden = false;
      return;
    }
  }

  const payload = { ssid: hotspotSsid.value.trim() };
  if (hotspotPassword.value) payload.password = hotspotPassword.value;
  try {
    await api("/api/settings/hotspot", {
      method: "PUT",
      body: JSON.stringify(payload),
    });
    hotspotBackdrop.hidden = true;
    // Intentionally NOT applied immediately - only active after a restart
    // (see removal of apply_hotspot_config in app.py). Inform user via popup
    // instead of silently pretending it is already active.
    hotspotRestartError.hidden = true;
    hotspotRestartBackdrop.hidden = false;
  } catch (err) {
    hotspotError.textContent = err.message;
    hotspotError.hidden = false;
  }
});

hotspotRestartLater.addEventListener("click", () => {
  hotspotRestartBackdrop.hidden = true;
});

hotspotRestartNow.addEventListener("click", async () => {
  if (!confirm("Really restart the PC now?")) return;
  try {
    await api("/api/system/restart", { method: "POST" });
    hotspotRestartBackdrop.hidden = true;
  } catch (err) {
    hotspotRestartError.textContent = err.message;
    hotspotRestartError.hidden = false;
  }
});

// Additional security: Modals can also be closed by clicking on the
// darkened background or pressing the Escape key.
[loginBackdrop, editBackdrop, passwordBackdrop, powerBackdrop, hotspotBackdrop, hotspotRestartBackdrop].forEach((backdrop) => {
  backdrop.addEventListener("click", (e) => {
    if (e.target === backdrop) backdrop.hidden = true;
  });
});

document.addEventListener("keydown", (e) => {
  if (e.key !== "Escape") return;
  loginBackdrop.hidden = true;
  editBackdrop.hidden = true;
  passwordBackdrop.hidden = true;
  powerBackdrop.hidden = true;
  hotspotBackdrop.hidden = true;
});

(async function init() {
  await refreshAdminState();
  await loadSettings();
  await loadButtons();
})();
