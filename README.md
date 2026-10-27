# mymind for Firefox

[![Build](https://github.com/MRoiban/mymind-firefox/actions/workflows/build.yml/badge.svg)](https://github.com/MRoiban/mymind-firefox/actions/workflows/build.yml)

An **unofficial** build of the current [mymind](https://mymind.com) browser extension for Firefox and Firefox-based browsers like Zen, LibreWolf and Floorp.

The official Firefox add-on stopped at **2.0.2 (2021)**. The Chrome extension kept improving and is at **3.3.0**. This project converts the latest Chrome release into a Firefox add-on, adds a few Firefox-only improvements, and makes it easy to stay current.

> [!IMPORTANT]
> This repository does **not** contain mymind's code. `scripts/build.sh` downloads the official extension from the Chrome Web Store on your machine and patches it locally. Not affiliated with or endorsed by mymind, Inc.

## What you get

Everything the Chrome extension has that the old Firefox add-on doesn't:

- **Save the page** from the toolbar button or **Alt+Shift+M**. Saves include a screenshot of the visible page.
- **Search your mind** from the address bar: type `mm`, a space, then your query.
- **Right-click → Add to my mind** on links, images, video, audio and selected text. Selections keep their formatting.
- **Tags and notes** right in the save toast, with a persistent tag cache for instant suggestions.
- **Esc** closes the toast. A `✕` badge appears on pages that can't be saved.
- Works with mymind's current API (tag and note endpoints changed since 2.0.2).

Plus some Firefox-only extras:

- **Right-click any post or card** to save *that post*, not the whole page. It recognises X, YouTube (including hover previews), Reddit, Instagram, Mastodon, Bluesky, Threads, and anything else that links a post from its timestamp. Elsewhere it saves the page.
- Fixes for places where Firefox behaves differently from Chrome. See [docs/PARITY.md](docs/PARITY.md).

## Quick start

Requirements: macOS or Linux with `python3`, `curl`, `unzip`, `zip` and `patch`. You also need Firefox 128+ or a browser based on it.

```sh
git clone https://github.com/MRoiban/mymind-firefox.git
cd mymind-firefox
scripts/build.sh
```

This produces `dist/mymind-firefox-<version>.xpi`.

### Install it

The add-on is unsigned, so how you install it depends on your browser:

| Browser | How |
|---|---|
| **Zen**, Firefox **Developer Edition / Nightly / ESR**, LibreWolf | In `about:config`, set `xpinstall.signatures.required` to `false`. Then go to `about:addons` → ⚙ → **Install Add-on From File…** and pick the `.xpi`. |
| **Firefox (release)** | Release builds refuse unsigned add-ons. Load it for the session from `about:debugging#/runtime/this-firefox` → **Load Temporary Add-on…**, or [sign it yourself](#signing-it-yourself). |

Then:

1. Sign in at [access.mymind.com](https://access.mymind.com) in the same browser.
2. If Firefox asks to let the add-on access `access.mymind.com`, allow it.
3. Optionally, change the shortcut in `about:addons` → ⚙ → **Manage Extension Shortcuts**.

The add-on reuses the id of the original mymind Firefox add-on. If you still have 2.0.2 installed, this replaces it in place.

## Updating to a new Chrome release

```sh
scripts/build.sh   # fetches the latest release, rebuilds firefox/ and the .xpi
```

Install the new `.xpi` the same way. A [weekly CI run](.github/workflows/build.yml) does the same build, so a red badge above means a new mymind release needs attention.

If the patch no longer applies:

1. Compare the releases: `diff -ru upstream/chrome-<old> upstream/chrome-<new>`.
2. Rebuild `firefox/` from the new release without the patch, port the Firefox changes by hand (the patch file shows exactly what they are), and check the new code against the Firefox gotchas in [docs/PARITY.md §6](docs/PARITY.md#6-status).
3. Run `python3 -I scripts/make-patch.py` to regenerate `patches/firefox.patch`.
4. Run `scripts/build.sh` again, then install and test it.

## How it works

```
Chrome Web Store ──curl──▶ upstream/chrome-<ver>/      pristine copy, kept for diffing
                                   │
              scripts/firefox-manifest.py              Chrome MV3 manifest → Firefox MV3
              patches/firefox.patch                    small JS changes for Firefox
                                   ▼
                            firefox/                   unpacked add-on (load it in about:debugging)
                                   ▼
                            dist/*.xpi                 installable add-on
```

`upstream/`, `firefox/` and `dist/` are generated and git-ignored.

| File | Purpose |
|---|---|
| `scripts/build.sh` | Download (or take a local `.crx` / directory), assemble, patch, package |
| `scripts/firefox-manifest.py` | Gecko id, event-page background, permissions, shortcut |
| `scripts/make-patch.py` | Regenerates the patch from your edits in `firefox/` |
| `patches/firefox.patch` | All Firefox-specific code changes, each commented in place |
| `docs/PARITY.md` | Feature-by-feature comparison of the old Firefox and current Chrome builds, every Firefox deviation and why, plus test notes |

## Making changes

1. Run `scripts/build.sh`, then edit files in `firefox/`.
2. Load `firefox/manifest.json` from `about:debugging` to try your changes.
3. Run `python3 -I scripts/make-patch.py` and commit `patches/firefox.patch`.

Keep the patch small: the less you diverge from Chrome, the easier updates are. Mark Firefox-specific code with a `// Firefox:` comment explaining why.

## Signing it yourself

Mozilla only signs add-ons whose id you own, and the default id belongs to mymind's listing. To sign your own copy:

1. Change `GECKO_ID` in `scripts/firefox-manifest.py` to your own id, such as `mymind-firefox@your.domain`.
2. Rebuild.
3. Sign it as an **unlisted** add-on: `npx web-ext sign --channel unlisted --source-dir firefox` with your AMO API keys.

Don't publish it on AMO: the code isn't yours to distribute.

## Licensing

The scripts, patch and docs in this repository are [MIT-licensed](LICENSE). Fork away.

The mymind extension itself is © mymind, Inc. and isn't included here or covered by that license. That's why the build downloads it rather than shipping it. Please don't commit or publish the generated `upstream/`, `firefox/` or `dist/` contents. "mymind" is a trademark of mymind, Inc.
