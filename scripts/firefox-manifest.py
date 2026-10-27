"""Derive the Firefox manifest from the Chrome (MV3) manifest.

usage: python3 -I scripts/firefox-manifest.py <chrome manifest.json> > firefox/manifest.json
"""
import json, sys

GECKO_ID = "{eb9e2174-ecaa-4a8f-8dc5-d7076687ac3f}"  # id of the original Firefox add-on
MIN_VERSION = "128.0"
SAVE_PAGE_KEY = "Alt+Shift+M"  # Ctrl/Cmd+Shift+S is Firefox Screenshots

m = json.load(open(sys.argv[1], encoding="utf-8"))

for key in ("update_url", "key"):
    m.pop(key, None)

# Insert gecko settings right after manifest_version to keep the file readable.
out = {}
for k, v in m.items():
    out[k] = v
    if k == "manifest_version":
        out["browser_specific_settings"] = {
            "gecko": {"id": GECKO_ID, "strict_min_version": MIN_VERSION}
        }
m = out

# Firefox doesn't support the "background" permission.
m["permissions"] = [p for p in m.get("permissions", []) if p != "background"]

# "menus" (Firefox-only) exposes targetElementId, so right-clicking a post can save
# that post instead of the page. No extra install warning.
if "menus" not in m["permissions"]:
    m["permissions"].append("menus")

# Firefox has no service workers for extensions; run it as a (module) event page.
bg = m.get("background", {})
if "service_worker" in bg:
    m["background"] = {"scripts": [bg["service_worker"]]}
    if bg.get("type"):
        m["background"]["type"] = bg["type"]

save = m.get("commands", {}).get("save-page")
if save and "suggested_key" in save:
    save["suggested_key"] = {"default": SAVE_PAGE_KEY}

json.dump(m, sys.stdout, ensure_ascii=False, indent=2)
sys.stdout.write("\n")
