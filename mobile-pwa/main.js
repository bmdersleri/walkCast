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

function statusLabel(status) {
  const map = {
    queued: "Queued",
    downloading: "Downloading",
    converting_mp3: "Converting",
    ready: "Ready",
    error: "Error",
  };
  return map[status] || status;
}

function getSavedOrder() {
  try {
    return JSON.parse(window.localStorage.getItem(ORDER_KEY) || "[]");
  } catch {
    return [];
  }
}

function saveOrder(order) {
  window.localStorage.setItem(ORDER_KEY, JSON.stringify(order));
}

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
  document.querySelectorAll("audio[data-item-id]").forEach((el) => {
    el.playbackRate = rate;
  });
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

async function handleTrackEnded(itemId) {
  const autoNextEnabled = autoplayNext.checked;
  const nextReadyId = autoNextEnabled ? getNextReadyId(itemId) : null;

  await fetch(`${API_BASE}/items/${itemId}/listen`, { method: "POST" });

  const confirmed = window.confirm("Delete from server?");
  if (confirmed) {
    await fetch(`${API_BASE}/items/${itemId}`, { method: "DELETE" });
  }

  await loadItems();

  if (autoNextEnabled && nextReadyId) {
    playAudioByItemId(nextReadyId);
  }
}

function enableDragAndDrop(card, itemId) {
  card.draggable = true;

  card.addEventListener("dragstart", () => {
    draggedItemId = itemId;
    card.classList.add("dragging");
  });

  card.addEventListener("dragend", () => {
    draggedItemId = null;
    card.classList.remove("dragging");
  });

  card.addEventListener("dragover", (event) => {
    event.preventDefault();
  });

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
    <div class="item-top">
      <h3 class="item-title">${safeTitle}</h3>
      <span>#${item.id}</span>
    </div>
    <div class="meta">
      <span class="badge">${duration}</span>
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
    audio.addEventListener("ended", async () => {
      await handleTrackEnded(item.id);
    });
    card.appendChild(audio);
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
  if (!currentItems.length) {
    itemsEl.textContent = "No items yet.";
    return;
  }

  currentItems.forEach((item) => itemsEl.appendChild(renderItem(item)));
  setPlaybackRateForAll();
}

async function loadItems() {
  itemsEl.innerHTML = "Loading...";
  const response = await fetch(`${API_BASE}/items`);
  if (!response.ok) {
    itemsEl.textContent = "Could not load playlist.";
    return;
  }

  const list = await response.json();
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
  const savedSpeed = window.localStorage.getItem(SPEED_KEY) || "1";
  speedSelect.value = savedSpeed;

  const savedAutoplay = window.localStorage.getItem(AUTOPLAY_KEY);
  autoplayNext.checked = savedAutoplay === "true";
}

initPreferences();
loadItems();
setInterval(loadItems, 5000);
