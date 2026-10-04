const apiInput = document.getElementById("apiBase");
const saveConfigBtn = document.getElementById("saveConfig");
const saveActiveBtn = document.getElementById("saveActive");
const refreshBtn = document.getElementById("refresh");
const listEl = document.getElementById("list");
const activePlaylistEl = document.getElementById("activePlaylist");
const newPlaylistBtn = document.getElementById("newPlaylist");
const qualityRadioEls = Array.from(document.querySelectorAll('input[name="audioQuality"]'));
const serverDotEl = document.getElementById("serverDot");
const serverTextEl = document.getElementById("serverText");

const ORDER_KEY = "popupItemOrder";
const ORDER_PREFIX = "popupItemOrderByPlaylist:";
const messageEl = document.getElementById("message");
let actionInProgress = false;
let refreshVersion = 0;
const PLAYLIST_KEY = "popupPlaylists";
const ACTIVE_PLAYLIST_KEY = "popupActivePlaylistId";
const QUALITY_KEY = "popupAudioQuality";

const STATUS_OFFLINE = "offline";
const STATUS_CONNECTING = "connecting";
const STATUS_ONLINE = "online";



function statusLabel(status) {
  const labels = { queued: "Queued", downloading: "Downloading", converting_mp3: "Converting", ready: "Ready", error: "Error" };
  return labels[status] || status;
}

function qualityLabel(value) {
  const labels = { good: "Good", medium: "Medium", high: "High" };
  return labels[value] || "Medium";
}

function formatSize(bytes) {
  if (!bytes || bytes <= 0) return "-- MB";
  return `${(bytes / (1024 * 1024)).toFixed(2)} MB`;
}

function progressModel(item) {
  const labels = { queued: "Queued", downloading: "Downloading audio…", converting_mp3: "Converting to MP3…", ready: "Ready", error: "Failed" };
  const active = ["queued", "downloading", "converting_mp3"].includes(item.status);
  return {
    visible: Boolean(labels[item.status]),
    percent: active ? 100 : item.status === "ready" ? 100 : 0,
    label: labels[item.status] || "",
    className: active ? "progress-active is-indeterminate" : item.status === "ready" ? "progress-ready" : "progress-error",
  };
}

function notify(message, isError = false) {
  messageEl.textContent = message;
  messageEl.className = isError ? "message error" : "message success";
  messageEl.hidden = !message;
  messageEl.setAttribute("role", isError ? "alert" : "status");
}

async function runAction(task, successMessage = "") {
  if (actionInProgress) return;
  actionInProgress = true;
  ++refreshVersion;
  const controls = Array.from(document.querySelectorAll("button, input, select"));
  const disabled = controls.map((control) => control.disabled);
  controls.forEach((control) => { control.disabled = true; });
  notify("");
  try {
    const result = await task();
    if (result !== false && successMessage) notify(successMessage);
    return result;
  } catch (error) {
    notify(error.message || "Operation failed. Please try again.", true);
    return false;
  } finally {
    controls.forEach((control, index) => { control.disabled = disabled[index]; });
    actionInProgress = false;
  }
}

function normalizeApiBase(value) {
  let url;
  try { url = new URL(value.trim()); } catch { throw new Error("Enter a valid HTTP or HTTPS API address."); }
  if (!["http:", "https:"].includes(url.protocol) || url.username || url.password || url.search || url.hash) {
    throw new Error("Use an HTTP or HTTPS API address without credentials, query parameters or a fragment.");
  }
  return url.href.replace(/\/+$/, "");
}

function permissionOrigin(apiBase) {
  const url = new URL(apiBase);
  return `${url.protocol}//${url.hostname}/*`;
}

async function apiRequest(apiBase, path, options = {}) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 10000);
  try {
    const response = await fetch(`${apiBase}${path}`, { ...options, signal: controller.signal });
    if (!response.ok) {
      let detail = "";
      try {
        const body = await response.json();
        if (typeof body.detail === "string") detail = `: ${body.detail}`;
      } catch { /* Some servers return non-JSON errors. */ }
      throw new Error(`Server returned HTTP ${response.status}${detail}`);
    }
    return response.status === 204 ? null : await response.json();
  } catch (error) {
    if (error.name === "AbortError") throw new Error("Server request timed out. Please try again.");
    if (error instanceof TypeError) throw new Error("Could not reach the server. Check the address and access permission.");
    throw error;
  } finally {
    clearTimeout(timer);
  }
}

function setServerStatus(status) {
  serverDotEl.classList.remove("is-online", "is-offline", "is-connecting");
  if (status === STATUS_ONLINE) {
    serverDotEl.classList.add("is-online");
    serverTextEl.textContent = "Server online";
    return;
  }
  if (status === STATUS_CONNECTING) {
    serverDotEl.classList.add("is-connecting");
    serverTextEl.textContent = "Checking server";
    return;
  }
  serverDotEl.classList.add("is-offline");
  serverTextEl.textContent = "Server offline";
}



async function getApiBase() {
  const cfg = await chrome.storage.local.get(["apiBase"]);
  return cfg.apiBase || "http://127.0.0.1:8000/api/v1";
}

async function setApiBase(value) { await chrome.storage.local.set({ apiBase: value }); }

async function getOrder(playlistId) {
  const key = `${ORDER_PREFIX}${playlistId}`;
  const data = await chrome.storage.local.get([key, ORDER_KEY]);
  // Keep the legacy order as a migration fallback for each playlist.
  return Array.isArray(data[key]) ? data[key] : Array.isArray(data[ORDER_KEY]) ? data[ORDER_KEY] : [];
}

async function setOrder(playlistId, order) {
  await chrome.storage.local.set({ [`${ORDER_PREFIX}${playlistId}`]: order });
}

async function getPlaylists() {
  const data = await chrome.storage.local.get([PLAYLIST_KEY]);
  const playlists = Array.isArray(data[PLAYLIST_KEY]) ? data[PLAYLIST_KEY] : [];
  if (!playlists.length) {
    const fallback = [{ id: 1, name: "Default" }];
    await chrome.storage.local.set({ [PLAYLIST_KEY]: fallback });
    return fallback;
  }
  return playlists;
}

async function setPlaylists(playlists) {
  await chrome.storage.local.set({ [PLAYLIST_KEY]: playlists });
}

async function getActivePlaylistId() {
  const data = await chrome.storage.local.get([ACTIVE_PLAYLIST_KEY]);
  const playlists = await getPlaylists();
  const firstId = playlists[0]?.id ?? 1;
  return Number.isInteger(data[ACTIVE_PLAYLIST_KEY]) ? data[ACTIVE_PLAYLIST_KEY] : firstId;
}

async function setActivePlaylistId(playlistId) {
  await chrome.storage.local.set({ [ACTIVE_PLAYLIST_KEY]: playlistId });
}

async function getAudioQuality() {
  const data = await chrome.storage.local.get([QUALITY_KEY]);
  const value = data[QUALITY_KEY];
  if (value === "good" || value === "medium" || value === "high") {
    return value;
  }
  return "medium";
}

async function setAudioQuality(quality) {
  await chrome.storage.local.set({ [QUALITY_KEY]: quality });
}

function getSelectedQualityFromUI() {
  const selected = qualityRadioEls.find((el) => el.checked);
  return selected?.value || "medium";
}

function setSelectedQualityToUI(quality) {
  qualityRadioEls.forEach((el) => {
    el.checked = el.value === quality;
  });
}

function playlistNameById(playlists, id) {
  return playlists.find((playlist) => playlist.id === id)?.name || "Unknown";
}

async function renderPlaylistControls() {
  const playlists = await getPlaylists();
  const activePlaylistId = await getActivePlaylistId();

  activePlaylistEl.innerHTML = "";
  playlists.forEach((playlist) => {
    const option = document.createElement("option");
    option.value = String(playlist.id);
    option.textContent = playlist.name;
    if (playlist.id === activePlaylistId) option.selected = true;
    activePlaylistEl.appendChild(option);
  });

  if (!playlists.some((playlist) => playlist.id === activePlaylistId)) {
    const fallbackId = playlists[0]?.id ?? 1;
    activePlaylistEl.value = String(fallbackId);
    await setActivePlaylistId(fallbackId);
  }
}

async function createPlaylist() {
  const name = prompt("Playlist name?");
  if (!name) return false;

  const trimmed = name.trim();
  if (!trimmed) return false;

  const playlists = await getPlaylists();
  const exists = playlists.some((playlist) => playlist.name.toLowerCase() === trimmed.toLowerCase());
  if (exists) {
    throw new Error("Playlist name already exists.");
  }

  const maxId = playlists.reduce((max, playlist) => Math.max(max, playlist.id), 0);
  const next = [...playlists, { id: maxId + 1, name: trimmed }];
  await setPlaylists(next);
  await setActivePlaylistId(maxId + 1);
  await renderPlaylistControls();
}

async function mergeAndSortByOrder(items, playlistId) {
  const itemIds = items.map((item) => item.id);
  const savedOrder = (await getOrder(playlistId)).filter((id) => itemIds.includes(id));
  const missing = itemIds.filter((id) => !savedOrder.includes(id));
  const merged = [...savedOrder, ...missing];
  await setOrder(playlistId, merged);

  const orderMap = new Map(merged.map((id, idx) => [id, idx]));
  return [...items].sort((a, b) => (orderMap.get(a.id) ?? 99999) - (orderMap.get(b.id) ?? 99999));
}

async function moveItem(itemId, direction) {
  const playlistId = Number(activePlaylistEl.value);
  const order = await getOrder(playlistId);
  const idx = order.indexOf(itemId);
  if (idx < 0) return;

  if (direction === "up" && idx > 0) {
    [order[idx - 1], order[idx]] = [order[idx], order[idx - 1]];
  } else if (direction === "down" && idx < order.length - 1) {
    [order[idx], order[idx + 1]] = [order[idx + 1], order[idx]];
  } else {
    return;
  }

  await setOrder(playlistId, order);
  await loadItems();
}

async function changeItemPlaylist(apiBase, itemId, playlistId) {
  const playlists = await getPlaylists();
  const playlistName = playlistNameById(playlists, playlistId);
  await apiRequest(apiBase, `/items/${itemId}`, {
    method: "PATCH",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ playlist_id: playlistId, playlist_name: playlistName }),
  });
}

function renderItem(apiBase, item, index, total, playlists) {
  const card = document.createElement("article");
  card.className = "card";

  const duration = item.duration || "--:--";
  const title = item.title || "Title pending...";
  const currentPlaylistName = playlistNameById(playlists, item.playlist_id || playlists[0]?.id || 1);
  const progress = progressModel(item);
  const titleEl = document.createElement("div");
  titleEl.className = "title";
  titleEl.textContent = title;
  card.appendChild(titleEl);
  const meta = document.createElement("div");
  meta.className = "meta";
  const badges = [
    [duration, ""], [formatSize(item.file_size_bytes), ""], [currentPlaylistName, ""],
    [qualityLabel(item.audio_quality), ""],
    [statusLabel(item.status), item.status === "ready" ? "ready" : item.status === "error" ? "error" : ""],
  ];
  if (item.is_listened) badges.push(["Listened", "ready"]);
  badges.forEach(([text, className]) => {
    const badge = document.createElement("span");
    badge.className = `badge ${className}`;
    badge.textContent = text;
    meta.appendChild(badge);
  });
  card.appendChild(meta);
  if (progress.visible) {
    const wrap = document.createElement("div");
    wrap.className = "progress-wrap";
    const label = document.createElement("div");
    label.className = "progress-label";
    label.textContent = progress.label;
    const track = document.createElement("div");
    track.className = "progress-track";
    const fill = document.createElement("div");
    fill.className = `progress-fill ${progress.className}`;
    fill.style.width = `${progress.percent}%`;
    track.appendChild(fill);
    wrap.appendChild(label);
    wrap.appendChild(track);
    card.appendChild(wrap);
  }


  const actions = document.createElement("div");
  actions.className = "actions";

  const playlistPicker = document.createElement("select");
  playlistPicker.className = "playlist-picker";
  playlists.forEach((playlist) => {
    const option = document.createElement("option");
    option.value = String(playlist.id);
    option.textContent = playlist.name;
    if ((item.playlist_id || playlists[0]?.id) === playlist.id) option.selected = true;
    playlistPicker.appendChild(option);
  });
  playlistPicker.setAttribute("aria-label", "Move to playlist");
  playlistPicker.addEventListener("change", () => {
    const previous = String(item.playlist_id || playlists[0]?.id || 1);
    const targetId = Number(playlistPicker.value);
    runAction(async () => {
      try { await changeItemPlaylist(apiBase, item.id, targetId); }
      catch (error) { playlistPicker.value = previous; throw error; }
      return await refreshAll("Item moved to playlist.");
    }, "Item moved to playlist.");
  });

  const upBtn = document.createElement("button");
  upBtn.className = "icon-btn secondary";
  upBtn.textContent = "↑";
  upBtn.title = "Move up";
  upBtn.setAttribute("aria-label", "Move up");
  upBtn.disabled = index === 0;
  upBtn.onclick = () => runAction(() => moveItem(item.id, "up"));

  const downBtn = document.createElement("button");
  downBtn.className = "icon-btn secondary";
  downBtn.textContent = "↓";
  downBtn.title = "Move down";
  downBtn.setAttribute("aria-label", "Move down");
  downBtn.disabled = index === total - 1;
  downBtn.onclick = () => runAction(() => moveItem(item.id, "down"));

  const deleteBtn = document.createElement("button");
  deleteBtn.className = "danger icon-btn";
  deleteBtn.textContent = "🗑";
  deleteBtn.title = "Delete";
  deleteBtn.setAttribute("aria-label", "Delete");
  deleteBtn.onclick = () => {
    if (!confirm(`Delete "${title}"? This also removes its audio from the server.`)) return;
    runAction(async () => {
      await apiRequest(apiBase, `/items/${item.id}`, { method: "DELETE" });
      return await refreshAll("Item deleted.");
    }, "Item deleted.");
  };

  actions.appendChild(playlistPicker);
  actions.appendChild(upBtn);
  actions.appendChild(downBtn);
  actions.appendChild(deleteBtn);
  card.appendChild(actions);
  return card;
}

async function loadItems({ background = false } = {}) {
  const version = ++refreshVersion;
  if (!background) setServerStatus(STATUS_CONNECTING);
  try {
    const apiBase = await getApiBase();
    const playlists = await getPlaylists();
    const activePlaylistId = Number(activePlaylistEl.value || (await getActivePlaylistId()));
    const itemsRaw = await apiRequest(apiBase, "/items");
    if (version !== refreshVersion) return false;
    if (!Array.isArray(itemsRaw)) throw new Error("The server returned an invalid queue.");
    const filtered = itemsRaw.filter((item) => (item.playlist_id || playlists[0]?.id || 1) === activePlaylistId);
    const items = await mergeAndSortByOrder(filtered, activePlaylistId);
    if (version !== refreshVersion) return false;
    setServerStatus(STATUS_ONLINE);
    listEl.replaceChildren();
    if (!items.length) listEl.textContent = "No items in this playlist.";
    else items.forEach((item, index) => listEl.appendChild(renderItem(apiBase, item, index, items.length, playlists)));
    return true;
  } catch (error) {
    if (version !== refreshVersion) return false;
    setServerStatus(STATUS_OFFLINE);
    // Keep the last queue visible when a refresh fails.
    if (!background) notify(`Could not refresh queue: ${error.message}`, true);
    return false;
  }
}

async function refreshAll(completedMessage = "") {
  const refreshed = await loadItems();
  if (!refreshed && completedMessage) {
    notify(`${completedMessage} ${messageEl.textContent}`, true);
  }
  return refreshed;
}

saveConfigBtn.addEventListener("click", () => {
  if (actionInProgress) return;
  let apiBase, permission;
  try {
    apiBase = normalizeApiBase(apiInput.value);
    // Request inside the user gesture, before any storage or network await.
    permission = chrome.permissions.request({ origins: [permissionOrigin(apiBase)] });
  } catch (error) { notify(error.message, true); return; }
  runAction(async () => {
    if (!await permission) throw new Error("Server access was denied. The previous address is still in use.");
    await setApiBase(apiBase);
    apiInput.value = apiBase;
    return await refreshAll("Server address saved.");
  }, "Server address saved.");
});

saveActiveBtn.addEventListener("click", () => runAction(async () => {
  const apiBase = await getApiBase();
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  if (!tab?.url || !/^https?:\/\//i.test(tab.url)) throw new Error("Open a video page with an HTTP or HTTPS address first.");
  const activePlaylistId = Number(activePlaylistEl.value || (await getActivePlaylistId()));
  const playlists = await getPlaylists();
  await apiRequest(apiBase, "/items", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      url: tab.url, playlist_id: activePlaylistId,
      playlist_name: playlistNameById(playlists, activePlaylistId),
      audio_quality: await getAudioQuality(),
    }),
  });
  return await refreshAll("Video added to queue.");
}, "Video added to queue."));

refreshBtn.addEventListener("click", () => runAction(refreshAll));
newPlaylistBtn.addEventListener("click", () => runAction(async () => {
  if (await createPlaylist() === false) return false;
  return await refreshAll("Playlist created.");
}, "Playlist created."));
activePlaylistEl.addEventListener("change", () => runAction(async () => {
  await setActivePlaylistId(Number(activePlaylistEl.value));
  return await loadItems();
}));
qualityRadioEls.forEach((el) => {
  el.addEventListener("change", () => {
    if (el.checked) runAction(() => setAudioQuality(getSelectedQualityFromUI()));
  });
});

let pollTimer;
async function poll() {
  if (!actionInProgress) await loadItems({ background: true });
  pollTimer = setTimeout(poll, 8000);
}
window.addEventListener("pagehide", () => clearTimeout(pollTimer));


(async function init() {
  await runAction(async () => {
    apiInput.value = await getApiBase();
    setSelectedQualityToUI(await getAudioQuality());
    await renderPlaylistControls();
    return await refreshAll();
  });
  pollTimer = setTimeout(poll, 8000);
})().catch((error) => notify(`Could not initialize extension: ${error.message}`, true));
