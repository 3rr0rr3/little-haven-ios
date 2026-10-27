"""Publish the tested candidate without changing main or the SideStore feed."""
import base64, hashlib, io, json, os, plistlib, subprocess, urllib.request, zipfile
from pathlib import Path

repo = os.environ['GITHUB_REPOSITORY']
source = os.environ['GITHUB_SHA']
token = os.environ['GH_TOKEN']
base = 'https://api.github.com/repos/' + repo

def api(path, data=None):
    request = urllib.request.Request(base + path, None if data is None else json.dumps(data).encode(),
        headers={'Authorization': 'Bearer ' + token, 'Accept': 'application/vnd.github+json', 'Content-Type': 'application/json'})
    with urllib.request.urlopen(request, timeout=90) as response:
        return json.load(response)

data = Path('LittleHaven-unsigned.ipa').read_bytes()
digest = hashlib.sha256(data).hexdigest()
assert digest == Path('LittleHaven-unsigned.ipa.sha256').read_text().split()[0]
with zipfile.ZipFile(io.BytesIO(data)) as archive:
    assert archive.testzip() is None
    info = plistlib.loads(archive.read('Payload/LittleHaven.app/Info.plist'))
assert info['CFBundleDisplayName'] == 'Brainstorm Haven'
assert info['CFBundleSupportedPlatforms'] == ['iPhoneOS']
version = info['CFBundleShortVersionString'].split('.')[0]
assert version == '56' and info['CFBundleVersion'] == '61'
branch = 'codex/download-v56-' + source[:8]
entries = []
def blob(path, content):
    result = api('/git/blobs', {'content': base64.b64encode(content).decode(), 'encoding':'base64'})
    expected = hashlib.sha1(b'blob ' + str(len(content)).encode() + b'\0' + content).hexdigest()
    assert result['sha'] == expected
    entries.append({'path':path, 'mode':'100644', 'type':'blob', 'sha':result['sha']})
blob('downloads/BrainstormHaven-56.ipa', data)
verification = {'source':source, 'version':'56.0', 'build':'61', 'size':len(data), 'sha256':digest}
blob('downloads/BrainstormHaven-56-verification.json', json.dumps(verification, indent=2).encode())
for report in sorted(Path('.').glob('ReleaseStartup-*-report.json')):
    blob('verification/v56/' + report.name, report.read_bytes())
for image in sorted(Path('.').glob('LittleHaven-response-painted-*.png')):
    reduced = Path('/tmp') / (image.stem+'.jpg')
    subprocess.run(['sips','-s','format','jpeg','-s','formatOptions','90','-Z','1100',str(image),'--out',str(reduced)],check=True,stdout=subprocess.DEVNULL)
    blob('previews/v56/' + image.stem+'.jpg', reduced.read_bytes())
for motion in sorted(Path('.').glob('LittleHaven-*-motion.mp4')):
    blob('previews/v56/'+motion.name,motion.read_bytes())

tree = api('/git/trees', {'base_tree':api('/git/commits/' + source)['tree']['sha'], 'tree':entries})
commit = api('/git/commits', {'message':'Verified Brainstorm Haven v56 build61 [skip ci]', 'tree':tree['sha'], 'parents':[source]})
api('/git/refs', {'ref':'refs/heads/' + branch, 'sha':commit['sha']})
url = 'https://raw.githubusercontent.com/' + repo + '/' + commit['sha'] + '/downloads/BrainstormHaven-56.ipa'
with urllib.request.urlopen(url, timeout=90) as response:
    downloaded = response.read()
    assert response.status == 200
assert len(downloaded) == len(data) and hashlib.sha256(downloaded).hexdigest() == digest
with zipfile.ZipFile(io.BytesIO(downloaded)) as archive:
    assert archive.testzip() is None
verification.update(binary_commit=commit['sha'], url=url, public_http_status=200, zip_verified=True)
Path('candidate-verification.json').write_text(json.dumps(verification, indent=2))
print(json.dumps(verification))
