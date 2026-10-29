"""Compare navigation workloads against the shipped v32 source on the same runner."""
import pathlib, subprocess, tempfile, urllib.request, json
root = pathlib.Path(__file__).resolve().parents[1]
files = ["Management.swift", "Office.swift", "RPGMap.swift", "Game.swift", "Motel.swift", "MotelWorld.swift"]
results = {}
with tempfile.TemporaryDirectory() as directory:
    temp = pathlib.Path(directory)
    for label in ["baseline", "optimized"]:
        sources = []
        for name in files:
            if label == "baseline":
                path = temp / name
                url = "https://raw.githubusercontent.com/3rr0rr3/little-haven-ios/d72c8a685cad2c90072340d48ac7b0206eafbeb4/LittleHaven/" + name
                path.write_bytes(urllib.request.urlopen(url, timeout=60).read())
            else:
                path = root / "LittleHaven" / name
            sources.append(str(path))
        binary = temp / label
        subprocess.run(["swiftc", "-O", *sources, str(root / "Tests/Performance/main.swift"), "-o", str(binary)], check=True)
        output = subprocess.check_output([str(binary)], text=True)
        print(label + "\n" + output, flush=True)
        results[label] = {parts[0]: {"milliseconds": float(parts[1]), "checksum": int(parts[2])}
                          for line in output.splitlines() if len(parts := line.split()) == 3}
for name in results["baseline"]:
    assert results["baseline"][name]["checksum"] == results["optimized"][name]["checksum"], name
    before = results["baseline"][name]["milliseconds"]
    after = results["optimized"][name]["milliseconds"]
    print(f"{name}: {before:.2f} ms -> {after:.2f} ms ({before / max(after, .001):.1f}x)", flush=True)
(root / "navigation-performance.json").write_text(json.dumps(results, indent=2))
