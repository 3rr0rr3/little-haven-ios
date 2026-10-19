"""Static map audit for hosts without Swift; does not replace Swift/iOS tests."""
from pathlib import Path
import re
from collections import deque

root = Path(__file__).resolve().parents[1]
source = (root/'LittleHaven/RPGMap.swift').read_text(encoding='utf-8-sig')
grounds = source.split('static let grounds:')[1]
blocked = set()
def region(x,y,w,h):
    blocked.update((a,b) for a in range(x,x+w) for b in range(y,y+h))
for x,y,w,h in re.findall(r'RPGRegion\(x:\s*(\d+),y:\s*(\d+),width:\s*(\d+),height:\s*(\d+)\)', grounds):
    region(*map(int,(x,y,w,h)))
for name in ['landscapeTrees','landscapeBenches']:
    line=next(s for s in source.splitlines() if f'static let {name} =' in s)
    blocked.update(tuple(map(int,p)) for p in re.findall(r'Tile\(x:(\d+),y:(\d+)\)',line))
for i in range(9): region(14+i%3*8,4+i//3*9,6,4)
for x in [17,25,33]: region(x,30,3,2)
for x in [47,57,67]: region(x-3,23,7,6)
seen={(6,35)}
queue=deque(seen)
while queue:
    x,y=queue.popleft()
    for p in [(x+1,y),(x-1,y),(x,y+1),(x,y-1)]:
        if 1<=p[0]<71 and 1<=p[1]<47 and p not in blocked and p not in seen:
            seen.add(p);queue.append(p)
management=(root/'LittleHaven/Management.swift').read_text(encoding='utf-8-sig')
line=next(s for s in management.splitlines() if 'static let chaosLocations=' in s)
fights=[tuple(map(int,p)) for p in re.findall(r'Tile\(x:(\d+),y:(\d+)\)',line)]
for x,y in fights:
    assert x<39 and y<35
    assert {(x,y),(x+1,y),(x,y+1)}<=seen, (x,y)
for p in [(54,14),(54,15),(47,29),(57,29),(67,29),(6,10)]:
    assert p in seen, p
print(f'PASS: {len(fights)} hotel incident sites, both fighters, responders, police, home and shops reachable.')
