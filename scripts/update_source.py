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
    "localizedDescription": "Separate family room inside the office, continuous emergency running, faster staff dispatch, visible job and supply status, physical maintenance and security tasks, and individual work posts replacing the shared break lounge.",
    "downloadURL": f"{asset_base}/LittleHaven-unsigned.ipa",
    "size": pathlib.Path("LittleHaven-unsigned.ipa").stat().st_size,
    "minOSVersion": info["MinimumOSVersion"],
}
app["versions"] = [entry] + [item for item in app["versions"] if item["version"] != version or item.get("buildVersion") != build]
app["subtitle"] = "Rooms, guests, night shifts and consequences."
app["localizedDescription"] = "Build and run an animated roadside Airb&b with day/night shifts, room condition, guest personalities, hourly and weekly contracts, dynamic rates, stock and ongoing bills. Hire and train staff, respond to complaints, develop up to eighteen rooms, operate a car wash and restaurant, monitor corridor cameras and night vision, and shape ethical, greedy, criminal or cult-friendly story paths. Existing saves and the family reception, weather, emergencies and stealth chapter are supported."
app["screenshotURLs"] = [f"{asset_base}/LittleHaven-title.png", f"{asset_base}/LittleHaven-management-board.png", f"{asset_base}/LittleHaven-management-events.png", f"{asset_base}/LittleHaven-management-cameras.png", f"{asset_base}/LittleHaven-management-night.png", f"{asset_base}/LittleHaven-parking-staff.png", f"{asset_base}/LittleHaven-pool.png", f"{asset_base}/LittleHaven-fight.png", f"{asset_base}/LittleHaven-stealth.png"]
source["subtitle"] = "A town dream and a roadside Airb&b"
body = {
    "message": f"Update SideStore feed for Little Haven {version} [skip ci]",
    "sha": response["sha"],
    "content": base64.b64encode((json.dumps(source, indent=2) + "\n").encode()).decode(),
}
pathlib.Path("source-update.json").write_text(json.dumps(body))
print(f"SideStore update prepared: {version} ({build}), {entry['size']} bytes")
