"""Validate shipped art without requiring an image library on the build runner."""
import hashlib, json, struct, zlib
from pathlib import Path
root=Path(__file__).resolve().parents[1]
manifest=json.loads((root/'ArtSources/CartoonV46/manifest.json').read_text(encoding='utf-8'))
assert len(manifest['assets'])==109
for asset in manifest['assets']:
    path=root/asset['path'];data=path.read_bytes()
    assert hashlib.sha256(data).hexdigest()==asset['sha256'],path
    assert data[:8]==b'\x89PNG\r\n\x1a\n',path
    assert list(struct.unpack('>II',data[16:24]))==asset['size'],path
    pos=8
    while pos<len(data):
        size=struct.unpack('>I',data[pos:pos+4])[0];chunk=data[pos+4:pos+8+size]
        assert zlib.crc32(chunk)&0xffffffff==struct.unpack('>I',data[pos+8+size:pos+12+size])[0],path
        pos+=12+size
    catalog=json.loads((path.parent/'Contents.json').read_text(encoding='utf-8'))
    assert catalog['images'][0]['filename']==path.name
project=(root/'LittleHaven.xcodeproj/project.pbxproj').read_text(encoding='utf-8')
assert 'PaintedArt.swift' in project and project.count('F00000000000000000000041')>=2
print('Validated 109 illustrated resources, PNG checksums, catalog entries and source registration.')
