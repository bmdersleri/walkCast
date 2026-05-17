const apiInput = document.getElementById("apiBase");
const saveConfigBtn = document.getElementById("saveConfig");
const saveActiveBtn = document.getElementById("saveActive");
const refreshBtn = document.getElementById("refresh");
const listEl = document.getElementById("list");

const ORDER_KEY = "popupItemOrder";

function statusLabel(status) {
  const labels = { queued: "Queued", downloading: "Downloading", converting_mp3: "Converting", ready: "Ready", error: "Error" };
  return labels[status] || status;
}

function formatSize(bytes) {
  if (!bytes || bytes <= 0) return "-- MB";
  return `${(bytes / (1024 * 1024)).toFixed(2)} MB`;
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

function renderItem(apiBase, item, index, total) {
  const card = document.createElement("article");
  card.className = "card";

  const duration = item.duration || "--:--";
  const title = item.title || "Title pending...";
  const listened = item.is_listened ? '<span class="badge ready">Listened</span>' : "";

  card.innerHTML = `
    <div class="title">${title}</div>
    <div class="meta">
      <span class="badge">${duration}</span>
      <span class="badge">${formatSize(item.file_size_bytes)}</span>
      <span class="badge ${item.status === "ready" ? "ready" : item.status === "error" ? "error" : ""}">${statusLabel(item.status)}</span>
      ${listened}
    </div>
  `;

  const actions = document.createElement("div");
  actions.className = "actions";

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

  actions.appendChild(upBtn);
  actions.appendChild(downBtn);
  actions.appendChild(deleteBtn);
  card.appendChild(actions);
  return card;
}

async function loadItems() {
  const apiBase = await getApiBase();
  listEl.textContent = "Loading...";
  try {
    const res = await fetch(`${apiBase}/items`);
    if (!res.ok) throw new Error("failed");
    const itemsRaw = await res.json();
    const items = await mergeAndSortByOrder(itemsRaw);

    listEl.innerHTML = "";
    if (!items.length) {
      listEl.textContent = "No items yet.";
      return;
    }

    items.forEach((item, index) => {
      listEl.appendChild(renderItem(apiBase, item, index, items.length));
    });
  } catch {
    listEl.textContent = "Could not connect backend.";
  }
}

saveConfigBtn.addEventListener("click", async () => { await setApiBase(apiInput.value.trim()); await loadItems(); });

saveActiveBtn.addEventListener("click", async () => {
  const apiBase = await getApiBase();
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  if (!tab?.url) return;
  await fetch(`${apiBase}/items`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ url: tab.url }),
  });
  await loadItems();
});

refreshBtn.addEventListener("click", loadItems);

(async function init() {
  apiInput.value = await getApiBase();
  await loadItems();
})();
