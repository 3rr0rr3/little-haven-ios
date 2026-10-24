"""Check the actual optimized simulator app's local startup record after UI tests."""
import json
from pathlib import Path
import sys

container, touch, destination = sys.argv[1:]
report = json.loads((Path(container) / 'Library/Application Support/startup-report.json').read_text())
assert report['build'] == '45.0 (50)', report
assert report['pending'] is False, report
required = [
    'hotel_body_begin', 'hotel_screen_deferred', 'hotelChrome_constructed',
    'hotelStartupTasks_constructed', 'hotelMovementTasks_constructed',
    'hotelSimulationTasks_constructed', 'hotelObservers_constructed',
    'hotelSheets_constructed', 'hotel_content_constructed', 'hotel_screen_begin',
    'hotel_fullscreen_constructed' if touch == 'true' else 'hotel_standard_constructed',
    'hotel_map_constructed', 'compatible_office_appeared',
    'office_art_draw_complete', 'hotel_stable',
]
assert all(step in report['steps'] for step in required), report
ordered = required[:10]
assert [report['steps'].index(s) for s in ordered] == sorted(report['steps'].index(s) for s in ordered), report
Path(destination).write_text(json.dumps(report, indent=2))
print('Optimized Release hotel construction, drawing and stable checkpoint verified; touch:', touch)
