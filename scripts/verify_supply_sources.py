"""The sole app-source delta is a DEBUG fixture initializer, excluded from Release."""
import os,subprocess
from pathlib import Path
base=os.environ['VERIFIED_BINARY_SOURCE']
subprocess.run(['git','diff','--exit-code',base,'HEAD','--','LittleHaven',':(exclude)LittleHaven/ContentView.swift','LittleHaven.xcodeproj','Tests/main.swift'],check=True)
old=subprocess.check_output(['git','show',base+':LittleHaven/ContentView.swift'])
new=Path('LittleHaven/ContentView.swift').read_bytes()
before=b'var sample=Game();sample.wakeUp();sample.motel!.initializeWorld();sample.motel!.enableManagement();sample.motel!.cash=700;'
after=before.replace(b'sample.wakeUp()',b'sample.coins=545;sample.wakeUp()')
assert new.count(after)==1 and new.replace(after,before)==old
start=new.index(b'#if DEBUG',new.index(b'private static func initialGame'))
assert start<new.index(after)<new.index(b'#endif',start)
print('Release sources and Foundation rules match the native binary; only a DEBUG fixture wakeup initializer changed.')

if os.environ.get('VERIFIED_UI_SOURCE'):
    subprocess.run(['git','diff','--exit-code',os.environ['VERIFIED_UI_SOURCE'],'HEAD','--','LittleHaven','LittleHaven.xcodeproj','LittleHavenUITests','Tests/main.swift'],check=True)
    print('Final app and UI test sources match the eighteen successful native UI executions.')
