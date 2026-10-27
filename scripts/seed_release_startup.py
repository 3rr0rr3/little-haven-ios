"""Seed an isolated CI simulator, never a player's device or the app source."""
import json, pathlib, plistlib, sys
container = pathlib.Path(sys.argv[1])
preferences = container / 'Library/Preferences/com.littlehaven.town.plist'
preferences.parent.mkdir(parents=True, exist_ok=True)
mode=sys.argv[3] if len(sys.argv)>3 else 'prologue'
if mode=='export-home':
    data=plistlib.loads(preferences.read_bytes())['littlehaven.save.v1']
    saved=json.loads(data)
    assert saved['motel']['world']['place']=='house',saved
    pathlib.Path('release-home-checkpoint.bin').write_bytes(data)
    print('Exported isolated simulator home checkpoint; player save files are untouched')
    raise SystemExit(0)
game = dict(player=dict(x=9,y=19), coins=545, gifts=list(range(7)), ownsHouse=False, inside=False, facing=0, steps=140)
state = {'littlehaven.save.v1': json.dumps(game).encode(), 'littlehaven.fullscreenTouch':sys.argv[2]=='true', 'littlehaven.compatibleOffice':True}
if mode=='home':
    state['littlehaven.save.v1']=pathlib.Path('release-home-checkpoint.bin').read_bytes()
    support=container/'Library/Application Support'
    support.mkdir(parents=True,exist_ok=True)
    previous={'id':'prior-build-home-startup','pending':True,'build':'55.0 (60)','system':'27.0','reason':'continue game','steps':['begin: continue game','continue_checkpoint_read','spritekit_ready_family-house']}
    (support/'startup-report.json').write_text(json.dumps(previous))
preferences.write_bytes(plistlib.dumps(state))
print('Seeded CI-only prologue checkpoint, touch:', state['littlehaven.fullscreenTouch'])
