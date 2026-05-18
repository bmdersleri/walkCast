const API_BASE = window.localStorage.getItem("walkcastApiBase") || "http://127.0.0.1:8000/api/v1";
const ORDER_KEY = "walkcastPlaylistOrder";
const SPEED_KEY = "walkcastPlaybackSpeed";
const AUTOPLAY_KEY = "walkcastAutoplayNext";

const itemsEl = document.getElementById("items");
const saveBtn = document.getElementById("saveBtn");
const urlInput = document.getElementById("urlInput");
const speedSelect = document.getElementById("speedSelect");
const autoplayNext = document.getElementById("autoplayNext");

let currentItems = [];
let draggedItemId = null;
let offlineIds = new Set();

function statusLabel(status) {
  const map = { queued: "Queued", downloading: "Downloading", converting_mp3: "Converting", ready: "Ready", error: "Error" };
  return map[status] || status;
}

function formatSize(bytes) {
  if (!bytes || bytes <= 0) return "-- MB";
  const mb = bytes / (1024 * 1024);
  return `${mb.toFixed(2)} MB`;
}

function getSavedOrder() {
  try { return JSON.parse(window.localStorage.getItem(ORDER_KEY) || "[]"); } catch { return []; }
}

function saveOrder(order) { window.localStorage.setItem(ORDER_KEY, JSON.stringify(order)); }

function mergeOrderWithItems(items) {
  const incomingIds = items.map((item) => item.id);
  const saved = getSavedOrder().filter((id) => incomingIds.includes(id));
  const missing = incomingIds.filter((id) => !saved.includes(id));
  const merged = [...saved, ...missing];
  saveOrder(merged);
  const idx = new Map(merged.map((id, index) => [id, index]));
  return [...items].sort((a, b) => (idx.get(a.id) ?? 99999) - (idx.get(b.id) ?? 99999));
}

function setPlaybackRateForAll() {
  const rate = Number(speedSelect.value);
  document.querySelectorAll("audio[data-item-id]").forEach((el) => { el.playbackRate = rate; });
}

function getNextReadyId(currentId) {
  const currentIndex = currentItems.findIndex((item) => item.id === currentId);
  for (let i = currentIndex + 1; i < currentItems.length; i += 1) {
    if (currentItems[i].status === "ready") return currentItems[i].id;
  }
  return null;
}

function playAudioByItemId(itemId) {
  const audio = document.querySelector(`audio[data-item-id="${itemId}"]`);
  if (!audio) return;
  audio.playbackRate = Number(speedSelect.value);
  audio.play().catch(() => {});
}

function openOfflineDb() {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open("walkcast-offline", 1);
    req.onupgradeneeded = () => req.result.createObjectStore("audio", { keyPath: "id" });
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}

async function saveOfflineAudio(itemId, blob) {
  const db = await openOfflineDb();
  await new Promise((resolve, reject) => {
    const tx = db.transaction("audio", "readwrite");
    tx.objectStore("audio").put({ id: itemId, blob, updatedAt: Date.now() });
    tx.oncomplete = resolve;
    tx.onerror = () => reject(tx.error);
  });
  db.close();
}

async function getOfflineAudio(itemId) {
  const db = await openOfflineDb();
  const row = await new Promise((resolve, reject) => {
    const tx = db.transaction("audio", "readonly");
    const req = tx.objectStore("audio").get(itemId);
    req.onsuccess = () => resolve(req.result || null);
    req.onerror = () => reject(req.error);
  });
  db.close();
  return row?.blob || null;
}

async function loadOfflineIds() {
  const db = await openOfflineDb();
  const ids = await new Promise((resolve, reject) => {
    const tx = db.transaction("audio", "readonly");
    const req = tx.objectStore("audio").getAllKeys();
    req.onsuccess = () => resolve(req.result || []);
    req.onerror = () => reject(req.error);
  });
  db.close();
  offlineIds = new Set(ids.map((id) => Number(id)));
}

async function handleTrackEnded(itemId) {
  const autoNextEnabled = autoplayNext.checked;
  const nextReadyId = autoNextEnabled ? getNextReadyId(itemId) : null;

  await fetch(`${API_BASE}/items/${itemId}/listen`, { method: "POST" });
  const confirmed = window.confirm("Delete from server?");
  if (confirmed) await fetch(`${API_BASE}/items/${itemId}`, { method: "DELETE" });

  await loadItems();
  if (autoNextEnabled && nextReadyId) playAudioByItemId(nextReadyId);
}

function enableDragAndDrop(card, itemId) {
  card.draggable = true;
  card.addEventListener("dragstart", () => { draggedItemId = itemId; card.classList.add("dragging"); });
  card.addEventListener("dragend", () => { draggedItemId = null; card.classList.remove("dragging"); });
  card.addEventListener("dragover", (event) => event.preventDefault());
  card.addEventListener("drop", (event) => {
    event.preventDefault();
    if (!draggedItemId || draggedItemId === itemId) return;
    const order = currentItems.map((item) => item.id);
    const fromIndex = order.indexOf(draggedItemId);
    const toIndex = order.indexOf(itemId);
    if (fromIndex < 0 || toIndex < 0) return;
    order.splice(fromIndex, 1);
    order.splice(toIndex, 0, draggedItemId);
    saveOrder(order);
    currentItems = mergeOrderWithItems(currentItems);
    renderList();
  });
}

function renderItem(item) {
  const card = document.createElement("article");
  card.className = "item-card";
  const safeTitle = item.title || "Title pending...";
  const duration = item.duration || "--:--";

  card.innerHTML = `
    <div class="item-top"><h3 class="item-title">${safeTitle}</h3><span>#${item.id}</span></div>
    <div class="meta">
      <span class="badge">${duration}</span>
      <span class="badge">${formatSize(item.file_size_bytes)}</span>
      <span class="badge ${item.status}">${statusLabel(item.status)}</span>
      ${item.is_listened ? '<span class="badge ready">Listened</span>' : ""}
    </div>
  `;

  const actions = document.createElement("div");
  actions.className = "actions";

  if (item.status === "ready") {
    const audio = document.createElement("audio");
    audio.controls = true;
    audio.dataset.itemId = String(item.id);
    audio.src = item.filepath ? `${API_BASE.replace("/api/v1", "")}/${item.filepath}` : "";
    audio.playbackRate = Number(speedSelect.value);
    audio.addEventListener("ended", async () => handleTrackEnded(item.id));
    card.appendChild(audio);

    const downloadBtn = document.createElement("button");
    downloadBtn.textContent = "Download";
    downloadBtn.onclick = () => {
      if (!item.filepath) return;
      const link = document.createElement("a");
      link.href = `${API_BASE.replace("/api/v1", "")}/${item.filepath}`;
      link.download = `${item.title || `track-${item.id}`}.mp3`;
      link.click();
    };
    actions.appendChild(downloadBtn);

    const offlineBtn = document.createElement("button");
    const offlineSaved = offlineIds.has(item.id);
    offlineBtn.textContent = offlineSaved ? "Offline Saved" : "Save Offline";
    offlineBtn.className = offlineSaved ? "offline-saved" : "";
    offlineBtn.onclick = async () => {
      if (!item.filepath) return;
      const res = await fetch(`${API_BASE.replace("/api/v1", "")}/${item.filepath}`);
      const blob = await res.blob();
      await saveOfflineAudio(item.id, blob);
      offlineIds.add(item.id);
      offlineBtn.textContent = "Offline Saved";
      offlineBtn.className = "offline-saved";
      window.alert("Saved for offline playback.");
    };
    actions.appendChild(offlineBtn);

    const playOfflineBtn = document.createElement("button");
    playOfflineBtn.textContent = "Play Offline";
    playOfflineBtn.onclick = async () => {
      const blob = await getOfflineAudio(item.id);
      if (!blob) {
        window.alert("No offline copy found. Please use Save Offline first.");
        return;
      }
      const offlineUrl = URL.createObjectURL(blob);
      audio.src = offlineUrl;
      audio.playbackRate = Number(speedSelect.value);
      await audio.play();
    };
    actions.appendChild(playOfflineBtn);
  }

  const deleteBtn = document.createElement("button");
  deleteBtn.className = "danger";
  deleteBtn.textContent = "Delete";
  deleteBtn.onclick = async () => {
    const confirmed = window.confirm("Are you sure you want to delete this track from server?");
    if (!confirmed) return;
    await fetch(`${API_BASE}/items/${item.id}`, { method: "DELETE" });
    await loadItems();
  };
  actions.appendChild(deleteBtn);
  card.appendChild(actions);

  enableDragAndDrop(card, item.id);
  return card;
}

function renderList() {
  itemsEl.innerHTML = "";
  if (!currentItems.length) { itemsEl.textContent = "No items yet."; return; }
  currentItems.forEach((item) => itemsEl.appendChild(renderItem(item)));
  setPlaybackRateForAll();
}

async function loadItems() {
  itemsEl.innerHTML = "Loading...";
  const response = await fetch(`${API_BASE}/items`);
  if (!response.ok) { itemsEl.textContent = "Could not load playlist."; return; }
  const list = await response.json();
  await loadOfflineIds();
  currentItems = mergeOrderWithItems(list);
  renderList();
}

saveBtn.addEventListener("click", async () => {
  const url = urlInput.value.trim();
  if (!url) return;
  await fetch(`${API_BASE}/items`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ url }),
  });
  urlInput.value = "";
  await loadItems();
});

speedSelect.addEventListener("change", () => {
  window.localStorage.setItem(SPEED_KEY, speedSelect.value);
  setPlaybackRateForAll();
});

autoplayNext.addEventListener("change", () => {
  window.localStorage.setItem(AUTOPLAY_KEY, String(autoplayNext.checked));
});

function initPreferences() {
  speedSelect.value = window.localStorage.getItem(SPEED_KEY) || "1";
  autoplayNext.checked = window.localStorage.getItem(AUTOPLAY_KEY) === "true";
}

initPreferences();
loadItems();
setInterval(loadItems, 5000);
