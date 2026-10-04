# walkCast Saver Chrome extension

## Load or update

1. Open `chrome://extensions` and enable **Developer mode**.
2. Click **Load unpacked** and select this `extension` directory.
3. When updating an existing installation, click **Reload** on its card.
4. Start the walkCast backend, open a video page and click the extension.

The default API address is `http://127.0.0.1:8000/api/v1`. To use another
server, enter its complete API address and click the checkmark. Chrome asks
for access to that server's host; denying access keeps the previous address.
Chrome host permissions apply to every port on the selected host.

Select a playlist and MP3 quality, then click **Save active tab**. Failed
requests show an error; controls are disabled during operations. Deleting
an item requires confirmation and also removes its server-side audio file.

Playlist definitions and per-playlist ordering are stored in this browser's
extension storage. Ordering is not synchronized with the mobile app. The
queue refreshes every eight seconds while the popup is open. Processing
indicators show the current phase; the backend does not report a real ETA.

## Regression checks

From the repository root, with Node.js installed:

```sh
node --test extension/tests/popup.test.cjs
node --check extension/popup.js
```

These tests mock Chrome APIs, the DOM and the backend. Validate the actual
Chrome permission prompt and a save/move/delete flow with your running
backend when testing a release.
