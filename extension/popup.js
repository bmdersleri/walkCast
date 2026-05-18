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
const PLAYLIST_KEY = "popupPlaylists";
const ACTIVE_PLAYLIST_KEY = "popupActivePlaylistId";
const QUALITY_KEY = "popupAudioQuality";

const STATUS_OFFLINE = "offline";
const STATUS_CONNECTING = "connecting";
const STATUS_ONLINE = "online";

const DOWNLOAD_ESTIMATE_SECONDS = 180;
const CONVERT_ESTIMATE_SECONDS = 60;

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

function formatRemaining(seconds) {
  if (seconds <= 0) return "<1m left";
  if (seconds < 60) return `${seconds}s left`;
  const min = Math.floor(seconds / 60);
  const sec = seconds % 60;
  return `${min}m ${sec}s left`;
}

function secondsSince(isoDate) {
  if (!isoDate) return 0;
  const dt = new Date(isoDate);
  if (Number.isNaN(dt.getTime())) return 0;
  return Math.max(0, Math.floor((Date.now() - dt.getTime()) / 1000));
}

function progressModel(item) {
  const elapsedFromCreated = secondsSince(item.created_at);
  const elapsedFromUpdated = secondsSince(item.updated_at) || elapsedFromCreated;

  if (item.status === "ready") {
    return { visible: true, percent: 100, label: "Ready", className: "progress-ready" };
  }

  if (item.status === "error") {
    return { visible: true, percent: 100, label: "Failed", className: "progress-error" };
  }

  if (item.status === "queued") {
    return { visible: true, percent: 5, label: "Queued", className: "progress-active" };
  }

  if (item.status === "downloading") {
    const used = Math.min(elapsedFromUpdated, DOWNLOAD_ESTIMATE_SECONDS);
    const pct = Math.min(70, 10 + Math.round((used / DOWNLOAD_ESTIMATE_SECONDS) * 60));
    const remaining = Math.max(0, DOWNLOAD_ESTIMATE_SECONDS - used);
    return {
      visible: true,
      percent: pct,
      label: `${formatRemaining(remaining)} (download)`,
      className: "progress-active",
    };
  }

  if (item.status === "converting_mp3") {
    const used = Math.min(elapsedFromUpdated, CONVERT_ESTIMATE_SECONDS);
    const pct = Math.min(95, 70 + Math.round((used / CONVERT_ESTIMATE_SECONDS) * 25));
    const remaining = Math.max(0, CONVERT_ESTIMATE_SECONDS - used);
    return {
      visible: true,
      percent: pct,
      label: `${formatRemaining(remaining)} (convert)`,
      className: "progress-active",
    };
  }

  return { visible: false, percent: 0, label: "", className: "progress-active" };
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

async function pingServer(apiBase) {
  setServerStatus(STATUS_CONNECTING);
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), 3000);

  try {
    const res = await fetch(`${apiBase}/items`, { method: "GET", signal: ctrl.signal });
    setServerStatus(res.ok ? STATUS_ONLINE : STATUS_OFFLINE);
  } catch {
    setServerStatus(STATUS_OFFLINE);
  } finally {
    clearTimeout(timer);
  }
}

async function getApiBase() {
  const cfg = await chrome.storage.local.get(["apiBase"]);
  return cfg.apiBase || "http://127.0.0.1:8000/api/v1";
}

async function setApiBase(value) { await chrome.storage.local.set({ apiBase: value }); }

async function getOrder() {
  const data = await chrome.storage.local.get([ORDER_KEY]);
  return Array.isArray(data[ORDER_KEY]) ? data[ORDER_KEY] : [];
}

async function setOrder(order) {
  await chrome.storage.local.set({ [ORDER_KEY]: order });
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
  if (!name) return;

  const trimmed = name.trim();
  if (!trimmed) return;

  const playlists = await getPlaylists();
  const exists = playlists.some((playlist) => playlist.name.toLowerCase() === trimmed.toLowerCase());
  if (exists) {
    alert("Playlist name already exists.");
    return;
  }

  const maxId = playlists.reduce((max, playlist) => Math.max(max, playlist.id), 0);
  const next = [...playlists, { id: maxId + 1, name: trimmed }];
  await setPlaylists(next);
  await setActivePlaylistId(maxId + 1);
  await renderPlaylistControls();
}

async function mergeAndSortByOrder(items) {
  const itemIds = items.map((item) => item.id);
  const savedOrder = (await getOrder()).filter((id) => itemIds.includes(id));
  const missing = itemIds.filter((id) => !savedOrder.includes(id));
  const merged = [...savedOrder, ...missing];
  await setOrder(merged);

  const orderMap = new Map(merged.map((id, idx) => [id, idx]));
  return [...items].sort((a, b) => (orderMap.get(a.id) ?? 99999) - (orderMap.get(b.id) ?? 99999));
}

async function moveItem(itemId, direction) {
  const order = await getOrder();
  const idx = order.indexOf(itemId);
  if (idx < 0) return;

  if (direction === "up" && idx > 0) {
    [order[idx - 1], order[idx]] = [order[idx], order[idx - 1]];
  } else if (direction === "down" && idx < order.length - 1) {
    [order[idx], order[idx + 1]] = [order[idx + 1], order[idx]];
  } else {
    return;
  }

  await setOrder(order);
  await loadItems();
}

async function changeItemPlaylist(apiBase, itemId, playlistId) {
  const playlists = await getPlaylists();
  const playlistName = playlistNameById(playlists, playlistId);
  await fetch(`${apiBase}/items/${itemId}`, {
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
  const listened = item.is_listened ? '<span class="badge ready">Listened</span>' : "";
  const currentPlaylistName = playlistNameById(playlists, item.playlist_id || playlists[0]?.id || 1);
  const progress = progressModel(item);

  card.innerHTML = `
    <div class="title">${title}</div>
    <div class="meta">
      <span class="badge">${duration}</span>
      <span class="badge">${formatSize(item.file_size_bytes)}</span>
      <span class="badge">${currentPlaylistName}</span>
      <span class="badge">${qualityLabel(item.audio_quality)}</span>
      <span class="badge ${item.status === "ready" ? "ready" : item.status === "error" ? "error" : ""}">${statusLabel(item.status)}</span>
      ${listened}
    </div>
    ${progress.visible ? `
      <div class="progress-wrap">
        <div class="progress-label">${progress.label}</div>
        <div class="progress-track">
          <div class="progress-fill ${progress.className}" style="width:${progress.percent}%"></div>
        </div>
      </div>
    ` : ""}
  `;

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
  playlistPicker.addEventListener("change", async () => {
    await changeItemPlaylist(apiBase, item.id, Number(playlistPicker.value));
    await loadItems();
  });

  const upBtn = document.createElement("button");
  upBtn.className = "icon-btn secondary";
  upBtn.textContent = "↑";
  upBtn.title = "Move up";
  upBtn.setAttribute("aria-label", "Move up");
  upBtn.disabled = index === 0;
  upBtn.onclick = async () => moveItem(item.id, "up");

  const downBtn = document.createElement("button");
  downBtn.className = "icon-btn secondary";
  downBtn.textContent = "↓";
  downBtn.title = "Move down";
  downBtn.setAttribute("aria-label", "Move down");
  downBtn.disabled = index === total - 1;
  downBtn.onclick = async () => moveItem(item.id, "down");

  const deleteBtn = document.createElement("button");
  deleteBtn.className = "danger icon-btn";
  deleteBtn.textContent = "🗑";
  deleteBtn.title = "Delete";
  deleteBtn.setAttribute("aria-label", "Delete");
  deleteBtn.onclick = async () => {
    await fetch(`${apiBase}/items/${item.id}`, { method: "DELETE" });
    await loadItems();
  };

  actions.appendChild(playlistPicker);
  actions.appendChild(upBtn);
  actions.appendChild(downBtn);
  actions.appendChild(deleteBtn);
  card.appendChild(actions);
  return card;
}

async function loadItems() {
  const apiBase = await getApiBase();
  const playlists = await getPlaylists();
  listEl.textContent = "Loading...";
  try {
    const res = await fetch(`${apiBase}/items`);
    if (!res.ok) throw new Error("failed");
    const itemsRaw = await res.json();
    const activePlaylistId = Number(activePlaylistEl.value || (await getActivePlaylistId()));
    const filtered = itemsRaw.filter((item) => (item.playlist_id || playlists[0]?.id || 1) === activePlaylistId);
    const items = await mergeAndSortByOrder(filtered);

    listEl.innerHTML = "";
    if (!items.length) {
      listEl.textContent = "No items in this playlist.";
      return;
    }

    items.forEach((item, index) => {
      listEl.appendChild(renderItem(apiBase, item, index, items.length, playlists));
    });
  } catch {
    listEl.textContent = "Could not connect backend.";
  }
}

async function refreshAll() {
  const apiBase = await getApiBase();
  await pingServer(apiBase);
  await loadItems();
}

saveConfigBtn.addEventListener("click", async () => {
  await setApiBase(apiInput.value.trim());
  await refreshAll();
});

saveActiveBtn.addEventListener("click", async () => {
  const apiBase = await getApiBase();
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  if (!tab?.url) return;
  const activePlaylistId = Number(activePlaylistEl.value || (await getActivePlaylistId()));
  const playlists = await getPlaylists();
  const activePlaylistName = playlistNameById(playlists, activePlaylistId);
  const audioQuality = await getAudioQuality();
  await fetch(`${apiBase}/items`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      url: tab.url,
      playlist_id: activePlaylistId,
      playlist_name: activePlaylistName,
      audio_quality: audioQuality,
    }),
  });
  await refreshAll();
});

refreshBtn.addEventListener("click", refreshAll);
newPlaylistBtn.addEventListener("click", async () => {
  await createPlaylist();
  await loadItems();
});

activePlaylistEl.addEventListener("change", async () => {
  await setActivePlaylistId(Number(activePlaylistEl.value));
  await loadItems();
});

qualityRadioEls.forEach((el) => {
  el.addEventListener("change", async () => {
    if (!el.checked) return;
    await setAudioQuality(getSelectedQualityFromUI());
  });
});

(async function init() {
  apiInput.value = await getApiBase();
  setSelectedQualityToUI(await getAudioQuality());
  await renderPlaylistControls();
  await refreshAll();
  setInterval(refreshAll, 8000);
})();
