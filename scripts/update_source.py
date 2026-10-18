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
    "localizedDescription": "Complete management expansion: day and night shifts, room types and wear, meaningful upgrades, guest needs, contracts and rates, inventory, bills and wages, staff stats, complaints, local demand, expansions, CCTV and story paths.",
    "downloadURL": f"{asset_base}/LittleHaven-unsigned.ipa",
    "size": pathlib.Path("LittleHaven-unsigned.ipa").stat().st_size,
    "minOSVersion": info["MinimumOSVersion"],
}
app["versions"] = [entry] + [item for item in app["versions"] if item["version"] != version or item.get("buildVersion") != build]
app["subtitle"] = "Run your Airb&b and car wash."
app["localizedDescription"] = "Run your Airb&b with animated guest emergencies, changing outdoor weather, and a paid car wash. Watch guests struggle in the pool, angry guests fight, and courtyard fires burn. Hire Diego to scrub and rinse parked guest cars for income. Clean rooms, serve breakfast, wash towels, water plants, repair equipment and carry luggage with visible tools and effects. Guest belongings have recognizable suitcase, watch and camera designs and animate into your hands when stolen. Existing family reception, staff, police events, room upgrades and saved games are supported."
app["screenshotURLs"] = [f"{asset_base}/LittleHaven-pool.png", f"{asset_base}/LittleHaven-fight.png", f"{asset_base}/LittleHaven-parking-staff.png", f"{asset_base}/LittleHaven-weather-storm.png", f"{asset_base}/LittleHaven-weather-snow.png", f"{asset_base}/LittleHaven-stealth.png", f"{asset_base}/LittleHaven-cleaning.png", f"{asset_base}/LittleHaven-office.png"]
source["subtitle"] = "A town dream and a roadside Airb&b"
body = {
    "message": f"Update SideStore feed for Little Haven {version} [skip ci]",
    "sha": response["sha"],
    "content": base64.b64encode((json.dumps(source, indent=2) + "\n").encode()).decode(),
}
pathlib.Path("source-update.json").write_text(json.dumps(body))
print(f"SideStore update prepared: {version} ({build}), {entry['size']} bytes")
