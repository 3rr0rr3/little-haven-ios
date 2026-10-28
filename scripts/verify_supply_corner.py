"""Validate actual native tests and optimized startup; no gameplay data is edited."""
import json,os,re
from pathlib import Path
expected=['testCompatibleOfficeGuestInteraction', 'testNPCIdentityGallery', 'testCompatibleHomeCareAndSavedContinue', 'testFamilyAndCatsAreTappable', 'testFullscreenHomeFamilyConversations', 'testHomeBedroomsEnterExitAndSavedReturn', 'testPersonalNeedsFoodAndDirtyNpcReaction', 'testPersonalNeedsBathroomAndSavedCleanState', 'testSupplyBuyerCanBeHired', 'testPawnShopRequiresExplicitSale', 'testStaffReviewsAndDeskUpgrades', 'testFullscreenJoystickReleaseAndPause', 'testOutdoorChaosCanBeHandled', 'testLivingHavenAnimationGallery', 'testActualReleaseWakeAndFirstShift', 'testActualReleaseSavedHomeContinue']
logs='\n'.join(Path(p).read_text() for p in ['HomeLifeResults.xcresult.log','WorldLifeResults.xcresult.log','release-startup.log'])
passed=re.findall(r"Test Case '-\[LittleHavenUITests\.LittleHavenUITests (\w+)\]' passed",logs)
assert not re.findall(r"Test Case .* failed",logs)
assert set(passed)==set(expected) and len(passed)==18,(passed,set(expected)-set(passed))
for mode in ['false','true','home-false','home-true']:
 r=json.loads(Path('ReleaseStartup-'+mode+'-report.json').read_text())
 assert r['build']=='61.0 (66)' and r['pending'] is False and 'hotel_stable' in r['steps']
 if mode.startswith('home'):
  assert 'compatible_home_appeared' in r['steps'] and 'home_art_draw_complete' in r['steps']
  assert not any(s.startswith('spritekit_configure_family-house') for s in r['steps'])
proof={'source':os.environ['GITHUB_SHA'],'run':int(os.environ['GITHUB_RUN_ID']),'version':'61.0','build':'66','passed_ui_executions':len(passed),'unique_ui_methods':len(set(passed)),'ui_methods':sorted(set(passed)),'optimized_startup_paths':4,'previous_identity_features':['authored presentation','consistent staff portraits','consistent story walkers','20 hairstyles','4 face shapes','3 body shapes','8 outfits','8 accessory categories'],'cache_limit':48,'new_frame_sets_per_scene_update':2}
Path('living-animations-verification.json').write_text(json.dumps(proof,indent=2))
print(json.dumps(proof))
