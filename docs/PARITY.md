# mymind extension: Firefox 2.0.2 → Chrome 3.3.0 parity

Sources compared (neither is included in this repo; `scripts/build.sh` downloads the Chrome one into `upstream/`):

| | Version | Origin |
|---|---|---|
| Firefox 2.0.2 | MV2 | The last official Firefox build, add-on id `{eb9e2174-ecaa-4a8f-8dc5-d7076687ac3f}`, released Nov 2021 (`mymind.com/wp-content/uploads/2021/11/…-2.0.2-fx.xpi`) |
| Chrome 3.3.0 | MV3 | Chrome Web Store `nmgcefdhjpjefhgcpocffdlibknajbmj`, latest as of 2026-10-27 |

These are identical in both: `vendor/tiptap.min.js`, `fonts/`, `icons/`, `images/`, and `components/editor.js` apart from a small polyfill header. All the differences are in the background logic, the notification toast, and the Instagram overlay.

---

## 1. User-facing features missing in Firefox

- [x] **Keyboard shortcut**: `commands.save-page` saves the current page. The default is `Ctrl+Shift+S` / `Cmd+Shift+S`. ⚠️ Firefox already uses `Ctrl+Shift+S` for Screenshots, so pick a different default; users can rebind it in `about:addons` → Manage Shortcuts.
- [x] **Omnibox search**: typing `mm <query>` in the address bar opens `https://access.mymind.com/everything?q=…`. It respects current tab, new tab and background tab. An empty query opens the home page.
- [x] **Page screenshot attached to saved pages**: after a page save returns an object id, `tabs.captureVisibleTab` (JPEG, q87) is POSTed to `/objects/{id}/attachments?type=screenshot` as a raw blob. This needs a new `api.postBlob`.
- [x] **"Add to my mind" on links**: the `link` context was added to the context menu. Firefox has the `linkUrl` branch but never shows the menu item on links.
- [x] **Richer selection saves**: the request now also sends `selection.htmlFragment`, the HTML of the selected range, and trims the text. If the DOM selection is empty, which happens in inputs, some iframes and the PDF viewer, it falls back to the context menu's `selectionText`. Empty selections are ignored.
- [x] **Saving mymind itself is refused**: on `*.mymind.com/(everything|spaces|serendipity)` it shows an "inception 🌀" toast and flashes a 🤯 badge instead of saving.
- [x] **Badge feedback on restricted pages**: when script injection fails (for example on `about:` pages, AMO, or the PDF viewer), it flashes a `✕` badge for 2s instead of failing silently.
- [x] **Esc closes the toast**: pressing Escape anywhere dismisses it, unless you're typing in the tag input or note editor.
- [x] **Install activation ping**: on first install only (not on update, which 2.0.2 also does), it opens `/extension` and POSTs `/browser-extension/activate {version}`. Failures are ignored.
- [x] **Card links**: the "Saved" / "Already in your mind" toasts link to `/everything#{id}` instead of `/cards#{id}`.

## 2. Backend API changes (likely broken in 2.0.2 today)

- [x] **Add tag**: `POST /objects/{id}/annotations {content}` became `POST /objects/{id}/tags {name}`. The message payload is now `objectId` instead of `card`.
- [x] **Remove tag**: the message was renamed `removeTag` → `deleteTag`. The endpoint `DELETE /annotations/{id}` is unchanged.
- [x] **Save note**: the message was renamed `saveNote` → `saveObjectNote` and now returns the JSON or `{error}`. The editor shows the "saved" check only on success.
- [x] **Status handling in `createObject`**:
  - 401 → "Your session is not valid. Please sign in." linking to `/signin`
  - 403 → "Forbidden"
  - any other non-OK status → shows the problem+json `detail`
  - 2.0.2 treated 403 as "session invalid" and had no 401 case.
- [x] **Return values**: `createObject` now returns the card (with `.status`) for both 200 ("already saved") and 201. 2.0.2 returned nothing on 200, so the screenshot step would never run for those.
- [x] **Error results**: bridge actions return `{ error: problem }` instead of throwing. The toast shows `error.detail` for tag errors.

## 3. Reliability and robustness fixes

- [x] **Module split**: `modules/api.js` contains the `API` class, `Problem` and `CookieSigner`. `tags.js`, `notification.js` and `util.js` are separate modules. `hasProblem` no longer crashes when there's no `Content-Type`.
- [x] **Persistent tag cache**: `TagController` keeps tags in `storage.local.tagCache`. It serves suggestions instantly, refreshes in the background with a single in-flight request, and keeps the cached tags if the refresh fails. 2.0.2 re-fetched tags on every save.
- [x] **Per-tab save dedupe**: a `savingTabs` set ignores rapid repeat clicks or shortcut presses on the same tab. The `processingUrl` reset now uses `finally`.
- [x] **Page HTML cap**: lowered from 32 MB to 5 MB. Before capturing, it dispatches a `mymind-extension:page:saving` DOM event on the page.
- [x] **Toast isolation**:
  - The shadow host is a `<mymind-root>` custom element that is `position:fixed`, max z-index, and top-right. The toast itself is `<mymind-notification>` instead of `div#mymind-notification`, so page CSS can't style them.
  - The CSS is loaded through `adoptedStyleSheets` (fetch, then `replaceSync`) instead of a `<link>`, and the host is appended only once the styles are ready.
  - `getShadow` / `getNotification` / `showUpgradeNotification` are now async.
- [x] **Toast lifecycle**: `dispose()` removes the keydown listener and clears the close and note timers. It also resets `mymind.notification`, which 2.0.2 did with the wrong handler names.
- [x] **Tags in the toast**:
  - Removing a tag updates the UI first, then sends the delete.
  - Adding a tag checks `result.error`.
  - `addTag(tag)` takes `{id,name}`.
  - The container class was renamed `mymind-tagstorage` → `mymind-tag-list`.
- [x] **Instagram overlay** (`instagramOverlay.*` → `social-integrations.*`):
  - It uses a class instead of an id.
  - It sets the `mymind.socialIntegration` marker.
  - It clears stale `data-alt` / `data-post-url` values between images.
  - It injects only on the top frame (`frameId === 0`).
  - The `webNavigation` listener is registered once. 2.0.2 could register it twice.
- [x] **CSS polish**:
  - Font fallbacks were added (`sans-serif` / `serif`).
  - The countdown bar now shrinks (100%→0) instead of growing.
  - The tag input gets `scrollbar-width:none`.
  - The upgrade CTA's broken `target=_blank"` was fixed.
  - A few `box-shadow` / `margin` / hover rules were dropped.

## 4. Platform migration (MV2 → MV3), adapted for Firefox

- [x] `manifest_version: 3`. Move `*://*.mymind.com/*` to `host_permissions: ["https://access.mymind.com/*"]`, and Instagram to `optional_host_permissions`.
- [x] Firefox has no `service_worker`. Use `"background": { "scripts": ["worker.js"], "type": "module" }`.
- [x] Add `browser_specific_settings.gecko.id = "{eb9e2174-ecaa-4a8f-8dc5-d7076687ac3f}"` so the add-on keeps the same id and storage. Also set a `strict_min_version`.
- [x] Change `browser_action` → `action` and the `"browser_action"` menu context → `"action"`. Change `tabs.executeScript` / `insertCSS` → `scripting.*`, and add the `scripting` permission.
- [x] `web_accessible_resources` becomes the object form with `matches`.
- [x] Remove `polyfills/browser-polyfill.js`. Firefox has `browser.*` natively, and Chrome's `self.browser ??= chrome` header is harmless.
- [x] Drop the `background` permission. Firefox doesn't support it and warns.
- [x] Replace `new URLPattern(...)` with a `new URL(e.url).hostname === "www.instagram.com"` check. It's simpler and doesn't depend on the Firefox version.
- [x] Check that `captureVisibleTab` works under `activeTab` for all three triggers: toolbar, shortcut and menu. If it doesn't, the screenshot is skipped (the save itself still works).

## 5. Do NOT port

- **Safari-only code in 2.0.2**: `isSafari` paths, `utils/safari-login-inject.js`, the OAuth `authorize`/`refresh_token` flow, `ensureGrantedAccess`, and the extra `mymind-settings` menu handler. Chrome removed all of this; both builds authenticate with the `_jwt` cookie on `access.mymind.com`.
- **Unused code in 3.3.0**: `modules/jose.js` (an HMAC JWT signer, probably groundwork for a future signer that replaces `CookieSigner`), `Reactive`/`Listener`/`Deferred` in `util.js`, `mymind.clientId`, and the `onClick` toast prop. Watch for these to get wired up in later Chrome releases.
- **The debug `console.log('update', props)`** in `components/notification.js`.

## 6. Status

All items in §1–§4 are ported. `firefox/` is the Chrome 3.3.0 source with a generated manifest and `patches/firefox.patch` applied. See the [README](../README.md) for the update workflow.

### Firefox-only deviations from Chrome
| Where | Change | Why |
|---|---|---|
| manifest | generated by `scripts/firefox-manifest.py`: gecko id, `background.scripts`, no `background` permission, adds `menus`, `Alt+Shift+M` shortcut | Firefox MV3 differences; `Ctrl/Cmd+Shift+S` is Firefox Screenshots |
| `worker.js` | `isInstagramUrl()` instead of `URLPattern` | avoids depending on a newer Gecko version |
| `worker.js` | `ensureHostAccess()` before saving (toolbar, shortcut, menu) | Firefox lets users revoke MV3 host permissions; without it the extension wrongly says "sign in" |
| `worker.js`, `modules/notification.js` | `injected?.result` guards; `✕` badge when the injection returns nothing | **Found while testing:** on restricted pages Firefox resolves `scripting.executeScript` with an empty result instead of rejecting, which crashed the save |
| `worker.js` + `menus` permission | "Add to my mind" also in `page`/`frame` contexts. Right-clicking inside a post or card saves that post's permalink (X status, YouTube watch/shorts, Reddit `shreddit-post`, timestamp links on Mastodon/Bluesky/Threads, Instagram `/p/`, `/reel/`); otherwise it saves the page | Neither 2.0.2 nor Chrome shows the item outside links, media or selections. Firefox's `menus.getTargetElement` makes post detection possible |
| `worker.js` | `tab ??= await getActiveTab()` in menu handlers | **Found while testing:** with the `menus` permission, Firefox passed `tab = null` to `onClicked` |
| `components/notification.js` | `<link>` fallback if `adoptedStyleSheets` fails; debug `console.log` removed | defensive (adoptedStyleSheets did work in testing) |

### Verified in Zen 1.23.4b (headless, throwaway profile, driven over Marionette)
- Loads as MV3 with no manifest warnings, and the host permission is granted on install.
- Toolbar save: the page is captured, the toast is injected into the shadow root with styles and font applied, and it hits the live `POST /objects`. The 401 handling path was confirmed with a fake `_jwt` cookie.
- It also works on a page with a strict CSP (github.com).
- Keyboard shortcut `Alt+Shift+M` fires, with no clashes in Zen's 127 keybindings.
- Omnibox `mm hello world` opens `/everything?q=hello%20world`.
- Context menu "Add to my mind" works on links and on text selections.
- Esc dismisses the toast.
- `✕` badge on `about:robots`, cleared after 2s.
- `captureVisibleTab` works under `activeTab` (about a 214 KB JPEG).

### Not verified (needs a signed-in mymind account)
- A successful save (200/201): the tag drawer, tag suggestions/add/remove, the note editor autosave, and the screenshot upload.
- The upgrade (402) toast.
- The Instagram overlay (needs the permission prompt to be approved).
- The inception guard: `/everything` redirects to `/signin` when logged out. The code is identical to Chrome's.
