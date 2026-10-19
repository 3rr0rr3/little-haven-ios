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

This Windows workspace has no Swift compiler or Xcode. The Swift tests, iOS build and in-game visual review must still run on a suitable host before release. No new IPA has been published.

Both static route audits passed. A Tree-sitter Swift parse comparison found no new syntax errors against the base revision; this does not check types or replace compilation. UI tests now use the reception PC, walk to the workbench, and check Team visibility before and after hiring.
