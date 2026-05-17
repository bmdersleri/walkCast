const API_BASE = window.localStorage.getItem("walkcastApiBase") || "http://127.0.0.1:8000/api/v1";

const itemsEl = document.getElementById("items");
const saveBtn = document.getElementById("saveBtn");
const urlInput = document.getElementById("urlInput");

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
    audio.src = item.filepath ? `${API_BASE.replace('/api/v1', '')}/${item.filepath}` : "";
    audio.addEventListener("ended", async () => {
      await fetch(`${API_BASE}/items/${item.id}/listen`, { method: "POST" });
      const confirmed = window.confirm("Delete from server?");
      if (confirmed) {
        await fetch(`${API_BASE}/items/${item.id}`, { method: "DELETE" });
      }
      await loadItems();
    });
    card.appendChild(audio);
  }

  const deleteBtn = document.createElement("button");
  deleteBtn.className = "danger";
  deleteBtn.textContent = "Delete";
  deleteBtn.onclick = async () => {
    await fetch(`${API_BASE}/items/${item.id}`, { method: "DELETE" });
    await loadItems();
  };
  actions.appendChild(deleteBtn);
  card.appendChild(actions);

  return card;
}

async function loadItems() {
  itemsEl.innerHTML = "Loading...";
  const response = await fetch(`${API_BASE}/items`);
  if (!response.ok) {
    itemsEl.textContent = "Could not load playlist.";
    return;
  }

  const list = await response.json();
  itemsEl.innerHTML = "";
  if (!list.length) {
    itemsEl.textContent = "No items yet.";
    return;
  }

  list.forEach((item) => itemsEl.appendChild(renderItem(item)));
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

loadItems();
setInterval(loadItems, 5000);
