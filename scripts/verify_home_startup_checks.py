"""Retain passed tests only when production and test sources are identical."""
import json,os,re,subprocess,textwrap
from pathlib import Path
BASE='6fba06dde6b81987ef972d9b5eb188616faf0ec2'
def source(path):return subprocess.check_output(['git','show',BASE+':'+path]).decode('utf-8')
subprocess.run(['git','diff','--exit-code',BASE,'HEAD','--','LittleHaven','LittleHaven.xcodeproj','LittleHavenUITests','Tests','scripts/render_app_icon.py'],check=True)
workflow=source('.github/workflows/ipa.yml')
focus=next(line for line in workflow.splitlines() if '-resultBundlePath CreativeResults.xcresult' in line)
broad=next(line for line in workflow.splitlines() if '-resultBundlePath TestResults.xcresult' in line)
focused=set(re.findall(r'-only-testing:LittleHavenUITests/LittleHavenUITests/(test\w+)',focus))
skipped=set(re.findall(r'-skip-testing:LittleHavenUITests/LittleHavenUITests/(test\w+)',broad))
assert focused==skipped and len(focused)==23
original=Path('original-home-job.log').read_text(encoding='utf-8')
pattern=r"Test Case '-\[LittleHavenUITests\.LittleHavenUITests (\w+)\]' passed"
prior=re.findall(pattern,original)
assert len(prior)==24 and set(prior)==focused,(len(prior),set(prior)-focused)
assert not re.findall(r"Test Case .* failed",original)
assert "KeyError: 'motel'" in original and 'seed_release_startup.py' in original
Path('run-home-broad.sh').write_text('set -euo pipefail\n'+broad.strip()+' 2>&1 | tee home-broad-ui.log\n')
current=Path('.github/workflows/ipa.yml').read_text(encoding='utf-8')
release=current.split('      - name: Test actual Release wake-up and saved home with compatible rendering\n')[1].split('        run: |\n',1)[1].split('      - name:',1)[0]
Path('run-home-release.sh').write_text(textwrap.dedent(release))
if os.environ.get('STARTUP_CHECKS_FINISHED'):
    later=Path('home-broad-ui.log').read_text(encoding='utf-8')+'\n'+Path('home-release-ui.log').read_text(encoding='utf-8')
    passed=re.findall(pattern,later)
    assert not re.findall(r"Test Case .* failed",later)
    expected=set(re.findall(r'func (test\w+)\(',source('LittleHavenUITests/LittleHavenUITests.swift')))
    assert len(passed)==52 and set(prior+passed)==expected,(len(passed),expected-set(prior+passed))
    assert len(expected)==73
    for mode in ['false','true']:
        for prefix in ['', 'home-']:
            report=json.loads(Path('ReleaseStartup-'+prefix+mode+'-report.json').read_text())
            assert report['build']=='57.0 (62)' and not report['pending'] and 'hotel_stable' in report['steps']
            if prefix:
                assert 'compatible_home_appeared' in report['steps'] and 'home_art_draw_complete' in report['steps']
                assert not any(s.startswith('spritekit_configure_family-house') for s in report['steps'])
    proof={'source':os.environ['GITHUB_SHA'],'production_and_tests_equal_to':BASE,'retained_run':40539158093,'verification_run':int(os.environ['GITHUB_RUN_ID']),'retained_ui_executions':24,'additional_ui_executions':52,'successful_ui_executions':76,'unique_ui_methods':73,'all_ui_methods_passed':True,'startup_modes':['office-normal','office-fullscreen','saved-home-normal','saved-home-fullscreen'],'prior_pending_build':'55.0 (60)','home_avoids_spritekit':True}
    Path('home-startup-verification.json').write_text(json.dumps(proof,indent=2))
    print(json.dumps(proof))
else:print('PASS: identical production/test files; retained 23 focused checks and small-iPhone startup; 48 remaining Debug tests and four Release executions selected')
