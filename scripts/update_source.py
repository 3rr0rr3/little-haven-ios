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
    "localizedDescription": "Autumn RPG art update: pixel characters, textured scenery and timber buildings. Explore the grounds and interiors with a movement stick, meet clients and collect payments in person, carry cleaning tools, make beds, collect trash, mop spills, customize physical rooms and expand the property. Existing motel saves are supported.",
    "downloadURL": f"{asset_base}/LittleHaven-unsigned.ipa",
    "size": pathlib.Path("LittleHaven-unsigned.ipa").stat().st_size,
    "minOSVersion": info["MinimumOSVersion"],
}
app["versions"] = [entry] + [item for item in app["versions"] if item["version"] != version or item.get("buildVersion") != build]
app["subtitle"] = "Walk, work and build your motel."
app["localizedDescription"] = "Wake up and walk freely around a roadside motel, its office, pool, parking and guest rooms. Meet arriving clients, assign rooms and collect their payments. Pick up tools at the office, then make beds, collect trash and mop spills inside each vacated room. Interact with paint cabinets, beds, the front desk and construction plots to customize and expand your property. Guests walk to their rooms and depart along the grounds. Sneak into occupied rooms, take belongings and escape before being caught. Save at the office or sleep to create checkpoints. Original pixel-art RPG characters and smooth eight-direction movement."
app["screenshotURLs"] = [f"{asset_base}/LittleHaven-motel.png", f"{asset_base}/LittleHaven-cleaning.png", f"{asset_base}/LittleHaven-stealth.png", f"{asset_base}/LittleHaven-wake.png", f"{asset_base}/LittleHaven-preview.png"]
source["subtitle"] = "A town dream and a roadside motel"
body = {
    "message": f"Update SideStore feed for Little Haven {version} [skip ci]",
    "sha": response["sha"],
    "content": base64.b64encode((json.dumps(source, indent=2) + "\n").encode()).decode(),
}
pathlib.Path("source-update.json").write_text(json.dumps(body))
print(f"SideStore update prepared: {version} ({build}), {entry['size']} bytes")
