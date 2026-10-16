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
    "localizedDescription": "Motel mayhem: good and bad guest reviews, hired housekeepers, groundskeepers and security, room upgrades, courtyard fires, pool rescues and outdoor fights. Character conversations now use illustrated dialogue boxes inside the game.",
    "downloadURL": f"{asset_base}/LittleHaven-unsigned.ipa",
    "size": pathlib.Path("LittleHaven-unsigned.ipa").stat().st_size,
    "minOSVersion": info["MinimumOSVersion"],
}
app["versions"] = [entry] + [item for item in app["versions"] if item["version"] != version or item.get("buildVersion") != build]
app["subtitle"] = "Walk, work and build your motel."
app["localizedDescription"] = "Run a roadside motel from an expanded family reception. Stay behind the desk while clients walk in, introduce themselves and request a room. Accept and collect payment or decline politely. Tap your gray tabby Chichu, calico Chichi, Samhil watching TV, or Hildarelys walking around to interact. The owner and Hildarelys use original photo-inspired cut-paper cartoon designs. Tap the office door to explore the grounds, clean rooms, customize and expand the motel. Sneaking and last-save recovery remain available. Existing saves are supported."
app["screenshotURLs"] = [f"{asset_base}/LittleHaven-dialogue.png", f"{asset_base}/LittleHaven-chaos.png", f"{asset_base}/LittleHaven-office.png", f"{asset_base}/LittleHaven-motel.png", f"{asset_base}/LittleHaven-cleaning.png", f"{asset_base}/LittleHaven-stealth.png", f"{asset_base}/LittleHaven-wake.png", f"{asset_base}/LittleHaven-preview.png"]
source["subtitle"] = "A town dream and a roadside motel"
body = {
    "message": f"Update SideStore feed for Little Haven {version} [skip ci]",
    "sha": response["sha"],
    "content": base64.b64encode((json.dumps(source, indent=2) + "\n").encode()).decode(),
}
pathlib.Path("source-update.json").write_text(json.dumps(body))
print(f"SideStore update prepared: {version} ({build}), {entry['size']} bytes")
