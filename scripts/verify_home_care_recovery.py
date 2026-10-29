"""Combine unchanged production build checks with a focused UI test repair."""
import json, os, re, subprocess, hashlib
from pathlib import Path

BASE='1232dffb4ad1b396e0d45ed1f2ac1e60a8f09bde'
FAILED='testRelocatedHomeBathroomDoorAndFridge'
def old(path):
    return subprocess.check_output(['git','show',BASE+':'+path]).decode('utf-8').replace('\r\n','\n')
def current(path):return Path(path).read_text(encoding='utf-8').replace('\r\n','\n')
subprocess.run(['git','diff','--exit-code',BASE,'HEAD','--','LittleHaven','LittleHaven.xcodeproj'],check=True)
path='LittleHavenUITests/LittleHavenUITests.swift'
def without_door_test(text):
    start=text.index('    func '+FAILED+'() {')
    end=text.index('    private func back(',start)
    return text[:start]+text[end:]
assert without_door_test(old(path))==without_door_test(current(path)), 'Only the failed UI method may change'
before='    m.world!.place = .house;m.world!.player=HomeBedroom.bathroom.homeApproach'
after='''    m.world!.place = .house;m.world!.player=Tile(x:2,y:7)
    for direction in [Tile(x:1,y:0),Tile(x:1,y:0),Tile(x:0,y:-1),Tile(x:0,y:-1),Tile(x:0,y:-1),Tile(x:0,y:-1)] {m.moveActor(dx:direction.x,dy:direction.y)}
    require(m.actorTile==HomeBedroom.bathroom.homeApproach,"The actual fridge-to-bathroom walking route is clear")'''
assert old('Tests/main.swift').replace(before,after,1)==current('Tests/main.swift')
log=Path('original-job.log').read_text(encoding='utf-8')
passed=re.findall(r"Test Case '-\[LittleHavenUITests\.LittleHavenUITests (\w+)\]' passed",log)
failed=re.findall(r"Test Case '-\[LittleHavenUITests\.LittleHavenUITests (\w+)\]' failed",log)
expected=set(re.findall(r'func (test\w+)\(',current(path)))
assert failed==[FAILED],failed
assert len(passed)==72 and set(passed)==expected-{FAILED},(len(passed),expected-set(passed))
assert log.count('Optimized Release hotel construction, drawing and stable checkpoint verified; touch:')==2
assert 'Executed 20 tests, with 0 failures' in log
if os.environ.get('RECOVERY_FINISHED'):
    focused=Path('home-care-ui.log').read_text(encoding='utf-8')
    names=re.findall(r"Test Case '-\[LittleHavenUITests\.LittleHavenUITests (\w+)\]' passed",focused)
    assert names==[FAILED],names
    assert not re.findall(r"Test Case .* failed",focused)
    assert 'Executed 1 test, with 0 failures' in focused
    reports=[]
    for mode in ['false','true']:
        report=json.loads(Path('ReleaseStartup-'+mode+'-report.json').read_text())
        assert report['build']=='56.0 (61)' and report['pending'] is False and 'hotel_stable' in report['steps']
        reports.append(mode)
    ipa=Path('LittleHaven-unsigned.ipa').read_bytes()
    assert hashlib.sha256(ipa).hexdigest()==Path('LittleHaven-unsigned.ipa.sha256').read_text().split()[0]
    proof={'binary_source':BASE,'verification_source':os.environ['GITHUB_SHA'],'original_run':40519529272,'focused_run':int(os.environ['GITHUB_RUN_ID']),'production_tree_unchanged':True,'original_successful_ui_executions':72,'focused_successful_ui_executions':1,'unique_ui_methods':len(expected),'all_ui_methods_passed':set(passed+names)==expected,'startup_modes':reports,'door_modes':['normal','fullscreen'],'sha256':hashlib.sha256(ipa).hexdigest(),'tap_probe':next((line for line in focused.splitlines() if 'Home care tap-count probe:' in line),'')}
    Path('home-care-recovery.json').write_text(json.dumps(proof,indent=2))
    print(json.dumps(proof))
else:print('PASS: identical production tree; all prior checks retained; only failed door UI method and an extra model path assertion changed')
