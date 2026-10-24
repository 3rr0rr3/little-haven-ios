"""Seed an isolated CI simulator, never a player's device or the app source."""
import json, pathlib, plistlib, sys
container = pathlib.Path(sys.argv[1])
preferences = container / 'Library/Preferences/com.littlehaven.town.plist'
preferences.parent.mkdir(parents=True, exist_ok=True)
game = dict(player=dict(x=9,y=19), coins=545, gifts=list(range(7)), ownsHouse=False, inside=False, facing=0, steps=140)
state = {'littlehaven.save.v1': json.dumps(game).encode(), 'littlehaven.fullscreenTouch':sys.argv[2]=='true', 'littlehaven.compatibleOffice':True}
preferences.write_bytes(plistlib.dumps(state))
print('Seeded CI-only prologue checkpoint, touch:', state['littlehaven.fullscreenTouch'])
