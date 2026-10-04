const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

function harness(initial = {}, initialize = false) {
  const nodes = [];
  class Element {
    constructor(tag = 'div') {
      this.tagName = tag; this.children = []; this.events = {}; this.disabled = false;
      this.value = ''; this.checked = false; this.style = {}; this.className = '';
      this.attributes = {}; this._text = ''; nodes.push(this);
      this.classList = {
        add: (value) => { this.className += ` ${value}`; },
        remove: (...values) => { this.className = this.className.split(' ').filter((c) => !values.includes(c)).join(' '); },
      };
    }
    set textContent(value) { this._text = String(value); this.children = []; }
    get textContent() { return this._text + this.children.map((c) => c.textContent).join(''); }
    set innerHTML(value) { assert.equal(value, '', 'Untrusted HTML must never be parsed'); this.replaceChildren(); }
    appendChild(child) { this.children.push(child); return child; }
    replaceChildren(...children) { this._text = ''; this.children = children; }
    setAttribute(key, value) { this.attributes[key] = value; }
    addEventListener(event, callback) { this.events[event] = callback; }
  }
  const ids = {};
  for (const id of ['apiBase', 'saveConfig', 'saveActive', 'refresh', 'list', 'activePlaylist', 'newPlaylist', 'serverDot', 'serverText', 'message']) {
    ids[id] = new Element(id === 'apiBase' ? 'input' : id === 'activePlaylist' ? 'select' : /^(save|refresh|new)/.test(id) ? 'button' : 'div');
  }
  ids.activePlaylist.value = '1';
  const radios = ['good', 'medium', 'high'].map((value) => { const el = new Element('input'); el.value = value; el.checked = value === 'medium'; return el; });
  const storage = structuredClone(initial);
  const calls = [];
  const permissions = [];
  const timers = new Map();
  let nextTimer = 1;
  const h = { ids, storage, calls, permissions, timers, confirmResult: true, tabUrl: 'https://example.com/video', granted: true };
  h.fetch = async () => ({ ok: true, status: 200, json: async () => [] });
  const context = vm.createContext({
    URL, AbortController, TypeError, console,
    document: {
      getElementById: (id) => ids[id], createElement: (tag) => new Element(tag),
      querySelectorAll: (selector) => selector.includes('audioQuality') ? radios : nodes.filter((el) => ['button', 'input', 'select'].includes(el.tagName)),
    },
    chrome: {
      storage: { local: {
        get: async (keys) => Object.fromEntries(keys.map((key) => [key, structuredClone(storage[key])])),
        set: async (data) => { Object.assign(storage, structuredClone(data)); },
      } },
      tabs: { query: async () => [{ url: h.tabUrl }] },
      permissions: { request: (request) => { permissions.push(request); return Promise.resolve(h.granted); } },
    },
    fetch: (url, options) => { calls.push({ url, options }); return h.fetch(url, options); },
    setTimeout: (fn, delay) => { const id = nextTimer++; timers.set(id, { fn, delay }); return id; },
    clearTimeout: (id) => timers.delete(id),
    confirm: () => h.confirmResult, prompt: () => 'Test playlist',
    window: { addEventListener() {} },
  });
  let source = fs.readFileSync(path.join(__dirname, '..', 'popup.js'), 'utf8');
  if (!initialize) source = source.slice(0, source.indexOf('(async function init()'));
  vm.runInContext(source, context);
  h.eval = (expression) => vm.runInContext(expression, context);
  h.set = (key, value) => { context[key] = value; };
  return h;
}
const tick = () => new Promise((resolve) => setImmediate(resolve));
const plain = (value) => JSON.parse(JSON.stringify(value));
const response = (data, status = 200) => ({ ok: status >= 200 && status < 300, status, json: async () => data });

test('legacy migration preserves order independently across playlist switches', async () => {
  const h = harness({ popupItemOrder: [2, 1, 4, 3] });
  h.set('first', [{ id: 1 }, { id: 2 }]); h.set('second', [{ id: 3 }, { id: 4 }]);
  assert.deepEqual(plain(await h.eval('mergeAndSortByOrder(first, 1)')).map((x) => x.id), [2, 1]);
  await h.eval('mergeAndSortByOrder(second, 2)');
  assert.deepEqual(plain(await h.eval('mergeAndSortByOrder(first, 1)')).map((x) => x.id), [2, 1]);
  assert.deepEqual(h.storage['popupItemOrderByPlaylist:2'], [4, 3]);
  h.set('first', [{ id: 1 }, { id: 5 }]);
  await h.eval('mergeAndSortByOrder(first, 1)');
  assert.deepEqual(h.storage['popupItemOrderByPlaylist:1'], [1, 5]);
  assert.deepEqual(h.storage.popupItemOrder, [2, 1, 4, 3]);
});

test('reordering one playlist leaves the other playlist unchanged', async () => {
  const h = harness({ 'popupItemOrderByPlaylist:1': [1, 2], 'popupItemOrderByPlaylist:2': [4, 3] });
  h.fetch = async () => response([{ id: 1, playlist_id: 1 }, { id: 2, playlist_id: 1 }]);
  await h.eval('moveItem(2, "up")');
  assert.deepEqual(h.storage['popupItemOrderByPlaylist:1'], [2, 1]);
  assert.deepEqual(h.storage['popupItemOrderByPlaylist:2'], [4, 3]);
});

test('titles, playlist names and status are rendered literally', () => {
  const h = harness();
  h.set('item', { id: 1, title: '<img src=x onerror=alert(1)>', duration: '<b>10</b>', status: '<svg onload=alert(1)>', playlist_id: 1 });
  h.set('playlists', [{ id: 1, name: '<script>unsafe</script>' }]);
  const card = h.eval('renderItem("http://localhost:8000/api/v1", item, 0, 1, playlists)');
  assert.ok(card.textContent.includes('<img src=x onerror=alert(1)>'));
  assert.ok(card.textContent.includes('<script>unsafe</script>'));
  assert.ok(card.textContent.includes('<svg onload=alert(1)>'));
});

test('HTTP errors are checked for every mutation method; 204 deletion succeeds', async () => {
  const h = harness();
  h.fetch = async () => response({ detail: 'Rejected' }, 422);
  for (const method of ['POST', 'PATCH', 'DELETE']) {
    await assert.rejects(h.eval(`apiRequest("http://localhost/api/v1", "/items/1", { method: "${method}" })`), /HTTP 422: Rejected/);
  }
  h.fetch = async () => ({ ok: true, status: 204, json: async () => { throw new Error('must not parse'); } });
  assert.equal(await h.eval('apiRequest("http://localhost/api/v1", "/items/1", { method: "DELETE" })'), null);
  assert.equal(h.timers.size, 0);
});

test('failed save shows an error, prevents duplicate submissions and restores controls', async () => {
  const h = harness(); let finish;
  h.fetch = () => new Promise((resolve) => { finish = resolve; });
  const saving = h.ids.saveActive.events.click();
  await tick();
  assert.equal(h.ids.saveActive.disabled, true);
  await h.ids.saveActive.events.click();
  assert.equal(h.calls.length, 1);
  finish(response({ detail: 'Cannot save this URL' }, 400)); await saving;
  assert.match(h.ids.message.textContent, /HTTP 400: Cannot save this URL/);
  assert.equal(h.ids.message.attributes.role, 'alert');
  assert.equal(h.ids.saveActive.disabled, false);
});

test('successful save gives feedback and refreshes once', async () => {
  const h = harness();
  h.fetch = async (_, options) => options.method === 'POST' ? response({ id: 7 }, 201) : response([{ id: 7, playlist_id: 1, title: 'New video' }]);
  await h.ids.saveActive.events.click();
  assert.equal(h.ids.message.textContent, 'Video added to queue.');
  assert.equal(h.calls.length, 2);
  assert.ok(h.ids.list.textContent.includes('New video'));
});

test('a successful save followed by a refresh failure still confirms the save', async () => {
  const h = harness();
  h.fetch = async (_, options) => options.method === 'POST' ? response({ id: 7 }, 201) : response({}, 503);
  await h.ids.saveActive.events.click();
  assert.match(h.ids.message.textContent, /Video added to queue/);
  assert.match(h.ids.message.textContent, /Could not refresh queue.*HTTP 503/);
  assert.equal(h.calls.length, 2);
});

test('restricted tabs cannot be submitted', async () => {
  const h = harness(); h.tabUrl = 'chrome://extensions';
  await h.ids.saveActive.events.click();
  assert.equal(h.calls.length, 0);
  assert.match(h.ids.message.textContent, /HTTP or HTTPS/);
});

test('delete cancellation sends no request; failed deletion leaves the queue intact', async () => {
  const h = harness(); h.set('item', { id: 1, title: 'Keep me', playlist_id: 1 }); h.set('playlists', [{ id: 1, name: 'Default' }]);
  const card = h.eval('renderItem("http://localhost/api/v1", item, 0, 1, playlists)');
  h.ids.list.appendChild(card);
  const del = card.children.at(-1).children.at(-1);
  h.confirmResult = false; del.onclick(); await tick();
  assert.equal(h.calls.length, 0);
  h.confirmResult = true; h.fetch = async () => response({ detail: 'Delete failed' }, 500);
  del.onclick(); await tick();
  assert.equal(h.calls.length, 1);
  assert.ok(h.ids.list.textContent.includes('Keep me'));
  assert.match(h.ids.message.textContent, /Delete failed/);
});

test('failed playlist move restores the original selection', async () => {
  const h = harness(); h.set('item', { id: 1, playlist_id: 1 }); h.set('playlists', [{ id: 1, name: 'One' }, { id: 2, name: 'Two' }]);
  const card = h.eval('renderItem("http://localhost/api/v1", item, 0, 1, playlists)');
  const picker = card.children.at(-1).children[0]; picker.value = '2';
  h.fetch = async () => response({ detail: 'Move failed' }, 500);
  picker.events.change(); await tick();
  assert.equal(picker.value, '1');
  assert.match(h.ids.message.textContent, /Move failed/);
});

test('API address validation, normalization and optional permission denial', async () => {
  const h = harness({ apiBase: 'http://localhost:8000/api/v1' });
  for (const value of ['', 'file:///tmp', 'https://user:secret@host/api', 'https://host/api?x=1', 'https://host/api#x']) {
    h.set('value', value); assert.throws(() => h.eval('normalizeApiBase(value)'), /address/);
  }
  assert.equal(h.eval('normalizeApiBase(" https://server.example:8443/api/v1/ ")'), 'https://server.example:8443/api/v1');
  h.ids.apiBase.value = 'https://server.example:8443/api/v1/'; h.granted = false;
  h.ids.saveConfig.events.click();
  assert.equal(h.permissions.length, 1, 'Permission must be requested during the click');
  assert.deepEqual(plain(h.permissions[0]), { origins: ['https://server.example/*'] });
  await tick();
  assert.equal(h.storage.apiBase, 'http://localhost:8000/api/v1');
  assert.equal(h.calls.length, 0);
  assert.match(h.ids.message.textContent, /access was denied/);
});

test('granted permission saves normalized address and makes only one refresh request', async () => {
  const h = harness(); h.ids.apiBase.value = 'https://server.example:8443/api/v1/';
  h.ids.saveConfig.events.click(); await tick();
  assert.equal(h.storage.apiBase, 'https://server.example:8443/api/v1');
  assert.equal(h.calls.length, 1);
  assert.equal(h.calls[0].url, 'https://server.example:8443/api/v1/items');
  assert.equal(h.ids.message.textContent, 'Server address saved.');
});

test('newest refresh wins when requests complete out of order', async () => {
  const h = harness(); const pending = [];
  h.fetch = () => new Promise((resolve) => pending.push(resolve));
  const older = h.eval('loadItems()'); await tick();
  const newer = h.eval('loadItems()'); await tick();
  pending[1](response([{ id: 2, playlist_id: 1, title: 'New result' }])); await newer;
  pending[0](response([{ id: 1, playlist_id: 1, title: 'Stale result' }])); await older;
  assert.ok(h.ids.list.textContent.includes('New result'));
  assert.ok(!h.ids.list.textContent.includes('Stale result'));
});

test('refresh failure preserves the last list and reports failure', async () => {
  const h = harness(); h.ids.list.textContent = 'Previous queue';
  h.fetch = async () => response({}, 503);
  assert.equal(await h.eval('refreshAll()'), false);
  assert.equal(h.ids.list.textContent, 'Previous queue');
  assert.match(h.ids.message.textContent, /HTTP 503/);
  assert.match(h.ids.serverDot.className, /is-offline/);
});

test('polling skips mutations and reschedules after completion', async () => {
  const h = harness(); h.eval('actionInProgress = true');
  await h.eval('poll()'); assert.equal(h.calls.length, 0);
  assert.ok([...h.timers.values()].some((timer) => timer.delay === 8000));
  h.eval('actionInProgress = false'); await h.eval('poll()');
  assert.equal(h.calls.length, 1);
});

test('network requests time out and release their timer', async () => {
  const h = harness();
  h.fetch = (_, { signal }) => new Promise((_, reject) => signal.addEventListener('abort', () => reject({ name: 'AbortError' })));
  const request = h.eval('apiRequest("http://localhost/api/v1", "/items")');
  const rejected = assert.rejects(request, /timed out/);
  [...h.timers.values()][0].fn(); await rejected;
  assert.equal(h.timers.size, 0);
});

test('processing status does not fabricate an ETA or percentage', () => {
  const h = harness();
  for (const status of ['queued', 'downloading', 'converting_mp3']) {
    h.set('item', { status }); const progress = h.eval('progressModel(item)');
    assert.match(progress.className, /is-indeterminate/);
    assert.doesNotMatch(progress.label, /left|%|remaining/i);
  }
});

test('manifest retains local permissions and offers server-specific optional access', () => {
  const manifest = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'manifest.json'), 'utf8'));
  assert.equal(manifest.manifest_version, 3);
  assert.ok(manifest.host_permissions.includes('http://127.0.0.1:8000/*'));
  assert.deepEqual(manifest.optional_host_permissions, ['http://*/*', 'https://*/*']);
});

test('startup restores preferences, locks actions during initialization and schedules polling', async () => {
  const h = harness({ popupAudioQuality: 'high', popupPlaylists: [{ id: 1, name: 'My queue' }] }, true);
  assert.equal(h.ids.saveActive.disabled, true);
  await h.ids.saveActive.events.click();
  await tick();
  assert.equal(h.calls.length, 1);
  assert.equal(h.ids.apiBase.value, 'http://127.0.0.1:8000/api/v1');
  assert.equal(h.eval('getSelectedQualityFromUI()'), 'high');
  assert.equal(h.ids.saveActive.disabled, false);
  assert.ok(h.ids.activePlaylist.textContent.includes('My queue'));
  assert.ok([...h.timers.values()].some((timer) => timer.delay === 8000));
});
