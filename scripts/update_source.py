"""Refresh the existing SideStore feed from the verified device build."""
import base64
import datetime
import json
import os
import pathlib
import plistlib
import sys

tag = sys.argv[1]
repository = os.environ["GH_REPO"]
response = json.loads(pathlib.Path("live-source-response.json").read_text())
source = json.loads(base64.b64decode(response["content"]))
app = next(item for item in source["apps"] if item["bundleIdentifier"] == "com.littlehaven.town")
info = plistlib.loads(pathlib.Path("device-build/Build/Products/Release-iphoneos/LittleHaven.app/Info.plist").read_bytes())
assert info["CFBundleIdentifier"] == app["bundleIdentifier"]
version = info["CFBundleShortVersionString"]
build = info["CFBundleVersion"]
asset_base = f"https://github.com/{repository}/releases/download/{tag}"
entry = {
    "version": version,
    "buildVersion": build,
    "date": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d"),
    "localizedDescription": "The motel chapter: wake up after the town prologue, manage three rooms, welcome guests, customize rooms and office, expand to nine rooms, and risk sneaking into occupied rooms. Getting caught restores your last checkpoint.",
    "downloadURL": f"{asset_base}/LittleHaven-unsigned.ipa",
    "size": pathlib.Path("LittleHaven-unsigned.ipa").stat().st_size,
    "minOSVersion": info["MinimumOSVersion"],
}
app["versions"] = [entry] + [item for item in app["versions"] if item["version"] != version or item.get("buildVersion") != build]
app["subtitle"] = "Your motel. Your rules. Your risk."
app["localizedDescription"] = "Begin with a cozy town dream. Raise the cottage fund and wake up with the keys to a three-room motel. Check in guests, clean rooms, customize furnishings and wall colors, upgrade your office, and build a nine-room business. Sneak into occupied rooms to take belongings, watch suspicion, avoid the guest, and escape by the door. Getting caught ends the run; load your last safe checkpoint. Save at the desk or start the next day. Original cut-paper cartoon characters and smooth hold-to-walk controls."
app["screenshotURLs"] = [f"{asset_base}/LittleHaven-motel.png", f"{asset_base}/LittleHaven-stealth.png", f"{asset_base}/LittleHaven-wake.png", f"{asset_base}/LittleHaven-preview.png"]
source["subtitle"] = "A town dream and a roadside motel"
body = {
    "message": f"Update SideStore feed for Little Haven {version} [skip ci]",
    "sha": response["sha"],
    "content": base64.b64encode((json.dumps(source, indent=2) + "\n").encode()).decode(),
}
pathlib.Path("source-update.json").write_text(json.dumps(body))
print(f"SideStore update prepared: {version} ({build}), {entry['size']} bytes")
