"""Host-independent accessibility audit; Swift model tests remain authoritative."""
from pathlib import Path
import re
from collections import deque
root = Path(__file__).resolve().parents[1]
source = (root/'LittleHaven/RPGMap.swift').read_text(encoding='utf-8-sig')
blocked = set()
for name in ['landscapeTrees', 'landscapeBenches']:
    line = next(line for line in source.splitlines() if f'static let {name} =' in line)
    blocked.update((int(x),int(y)) for x,y in re.findall(r'Tile\(x:(\d+),y:(\d+)\)',line))
grounds = source.split('static let grounds:')[1]
initial = grounds.split('var obstacles = ')[1].split('\n')[0]
for x,y,w,h in re.findall(r'RPGRegion\(x: (\d+),y: (\d+),width: (\d+),height: (\d+)\)',initial):
    blocked.update((a,b) for a in range(int(x),int(x)+int(w)) for b in range(int(y),int(y)+int(h)))
for i in range(9):
    x,y=14+i%3*8,4+i//3*9
    blocked.update((a,b) for a in range(x,x+6) for b in range(y,y+4))
for x in [17,25,33]: blocked.update((a,b) for a in range(x,x+3) for b in range(30,32))
seen={(6,35)}; queue=deque(seen)
while queue:
    x,y=queue.popleft()
    for p in [(x+1,y),(x-1,y),(x,y+1),(x,y-1)]:
        if 1<=p[0]<=38 and 1<=p[1]<=36 and p not in blocked and p not in seen:
            seen.add(p); queue.append(p)
services=(root/'LittleHaven/Management.swift').read_text(encoding='utf-8-sig').split('enum HotelService:')[1].split('var symbol')[0]
targets=[(int(x),int(y)) for x,y in re.findall(r'Tile\(x:(\d+),y:(\d+)\)',services)]
targets += [(16+i%3*8,8+i//3*9) for i in range(9)]
targets += [(6,9),(16,29),(6,23),(11,14)]
assert all(t in seen for t in targets), [t for t in targets if t not in seen]
print(f'PASS: {len(targets)} service, doorway and emergency destinations reachable; {len(seen)} reachable tiles.')
