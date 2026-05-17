const apiInput = document.getElementById("apiBase");
const saveConfigBtn = document.getElementById("saveConfig");
const saveActiveBtn = document.getElementById("saveActive");
const refreshBtn = document.getElementById("refresh");
const listEl = document.getElementById("list");

function statusLabel(status) {
  const labels = {
    queued: "Queued",
    downloading: "Downloading",
    converting_mp3: "Converting",
    ready: "Ready",
    error: "Error",
  };
  return labels[status] || status;
}

async function getApiBase() {
  const cfg = await chrome.storage.local.get(["apiBase"]);
  return cfg.apiBase || "http://127.0.0.1:8000/api/v1";
}

async function setApiBase(value) {
  await chrome.storage.local.set({ apiBase: value });
}

function renderItem(apiBase, item) {
  const card = document.createElement("article");
  card.className = "card";

  const duration = item.duration || "--:--";
  const title = item.title || "Title pending...";
  const listened = item.is_listened ? '<span class="badge ready">Listened</span>' : "";

  card.innerHTML = `
    <div class="title">${title}</div>
    <div class="meta">
      <span class="badge">${duration}</span>
      <span class="badge ${item.status === "ready" ? "ready" : item.status === "error" ? "error" : ""}">${statusLabel(item.status)}</span>
      ${listened}
    </div>
  `;

  const actions = document.createElement("div");
  actions.className = "actions";

  const deleteBtn = document.createElement("button");
  deleteBtn.className = "danger";
  deleteBtn.textContent = "Delete";
  deleteBtn.onclick = async () => {
    await fetch(`${apiBase}/items/${item.id}`, { method: "DELETE" });
    await loadItems();
  };
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

    const items = await res.json();
    listEl.innerHTML = "";
    if (!items.length) {
      listEl.textContent = "No items yet.";
      return;
    }

    items.forEach((item) => listEl.appendChild(renderItem(apiBase, item)));
  } catch {
    listEl.textContent = "Could not connect backend.";
  }
}

saveConfigBtn.addEventListener("click", async () => {
  await setApiBase(apiInput.value.trim());
  await loadItems();
});

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
