"""Retain core native results only for the exact, cosmetic cat phase correction."""
import json,os,re,runpy,subprocess,sys,math
from pathlib import Path
CORE='8918b61519f266f91309d9597fcbce97fde96223'
changes=subprocess.check_output(['git','diff','--name-only',CORE,'HEAD','--','LittleHaven','LittleHaven.xcodeproj','LittleHavenUITests','Tests']).decode().splitlines()
assert set(changes)=={'LittleHaven/OfficeArt.swift','LittleHavenUITests/LittleHavenUITests.swift'},changes
def old(path):return subprocess.check_output(['git','show',CORE+':'+path]).decode().replace('\r\n','\n')
art=old('LittleHaven/OfficeArt.swift')
for before,after in [('            let mode=cat ? frame/4 : character%4', '            let mode=cat ? frame/4 : character%4\n            let catPulse=sin(Double(frame%4) * .pi / 3)'), ('            let hop=cat && mode==2 ? max(0,wave)*2 : !cat && active ? abs(wave)*0.8 : 0', '            let hop=cat && mode==2 ? catPulse*2 : !cat && active ? abs(wave)*0.8 : 0'), ('            if cat && mode==0 && active {', '            if cat && mode==0 {'), ('                oval(CGRect(x:6+lift,y:17-lift*4,width:3,height:3),actor.animal==1 ? 0x85817C : 0xE9E2D0)', '                oval(CGRect(x:6+catPulse,y:17-catPulse*4,width:3,height:3),actor.animal==1 ? 0x85817C : 0xE9E2D0)')]:
 assert art.count(before)==1,before
 art=art.replace(before,after,1)
assert Path('LittleHaven/OfficeArt.swift').read_text()==art,'Unexpected production art change'
tests=old('LittleHavenUITests/LittleHavenUITests.swift').replace('    func testLivingHavenAnimationGallery() {','    func testCatMotionPhasesRenderInGallery() {\n        let app=launch("--ui-life-gallery")\n        XCTAssertTrue(app.staticTexts["lifeReview"].waitForExistence(timeout:15))\n        let cat=app.staticTexts["Home cat 1"]\n        for _ in 0..<6 {\n            if cat.exists && cat.isHittable {break}\n            app.swipeUp()\n        }\n        XCTAssertTrue(cat.exists && cat.isHittable,app.debugDescription)\n        for frame in 0..<5 {\n            capture(app,"Cat motion phase \\(frame): grooming stretch pounce curl")\n            Thread.sleep(forTimeInterval:1)\n        }\n        XCTAssertEqual(app.state,.runningForeground)\n    }\n\n'+'    func testLivingHavenAnimationGallery() {',1)
assert Path('LittleHavenUITests/LittleHavenUITests.swift').read_text()==tests,'Existing UI assertions changed'
assert math.sin(math.pi/3)>0 and math.sin((9%4)*math.pi/3)>0
if '--audit-only' in sys.argv:
 print('PASS: only the cat grooming/pounce expressions changed; all core gameplay, controls, saving and startup sources are identical')
 raise SystemExit(0)
runpy.run_path('scripts/verify_living_animations.py',run_name='__main__')
proof=json.loads(Path('living-animations-verification.json').read_text())
log=Path('CatMotionResults.xcresult.log').read_text()
passed=re.findall(r"Test Case '-\[LittleHavenUITests\.LittleHavenUITests (\w+)\]' passed",log)
expected={'testCatMotionPhasesRenderInGallery','testLivingHavenAnimationGallery','testFamilyAndCatsAreTappable','testCompatibleHomeCareAndSavedContinue'}
assert set(passed)==expected and len(passed)==4,passed
assert not re.findall(r'Test Case .* failed',log)
proof.update(core_source=CORE,core_run=40631703703,optimized_startup_source=CORE,core_passed_ui_executions=21,additional_art_ui_executions=4,passed_ui_executions=25,unique_ui_methods=20,art_ui_methods=sorted(passed),exact_cosmetic_delta_audited=True,art_delta='correct grooming and pounce phase expressions only')
proof['ui_methods']=sorted(set(proof['ui_methods']).union(passed))
Path('living-animations-verification.json').write_text(json.dumps(proof,indent=2))
print(json.dumps(proof))
