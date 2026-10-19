# Reception and neighborhood changes

- Management now opens at the reception computer. The Team HUD button appears only after hiring staff.
- Home decoration and renovation open at a physical workbench. Removed the room-wide decoration shortcuts and renovation sign.
- Chichu and Chichi offer Follow me / Stay here. They travel between grounds, reception, home and guest rooms. Waiting locations and follow state are included in checkpoints.
- Emergency locations stay on hotel grounds. Old city fights migrate back to the courtyard.
- Police register arrival immediately and open the pending case, including after loading an arrived case.
- The family house and garden use half their former footprint, with matching collision geometry and the original reachable entrance.
- The existing 2D environment uses subdued ground colors, grass strokes, material shading and tree/building shadows. Characters remain unchanged. This is not a 3D Arceus-style conversion.

## Validation

Run `python scripts/check_reception_routes.py` and `python scripts/check_landscape.py` for static route audits. New behavioral regression cases are included in `Tests/main.swift`.

Version 14.0 (18) was built on macOS through GitHub Actions. The candidate passed native model tests, the Release iPhoneOS build, all 23 simulator UI tests (zero failures), preview capture and IPA packaging. Linux model tests also passed after integration. Reception, home interior and terrain previews were visually inspected.

Both static route audits passed. A Tree-sitter Swift parse comparison found no new syntax errors against the base revision; this does not check types or replace compilation. UI tests now use the reception PC, walk to the workbench, and check Team visibility before and after hiring.

The new pet UI test takes both cats outside, leaves Chichu waiting and verifies Chichi still follows. Candidate IPA SHA256: `5f39d2e0f4d2fcb6c3e29e21560a5b9a9a70046e5403e9588b645c42b5c42b6e`. Its Info.plist reports version 14.0, build 18, iPhoneOS and minimum iOS 17. Physical-device installation remains untested.

Candidate run: https://github.com/3rr0rr3/little-haven-ios/actions/runs/39295792334

Integrated PR: https://github.com/3rr0rr3/little-haven-ios/pull/1

Official publication run: https://github.com/3rr0rr3/little-haven-ios/actions/runs/39298293654
