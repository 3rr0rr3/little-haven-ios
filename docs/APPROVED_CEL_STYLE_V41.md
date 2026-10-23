# Approved compact cel-shaded visual pass

The user approved the small character in `ArtSources/CelV41/approved-player-reference.png` and requested the same art across the game. That preview is the style authority: compact silhouette, large black glasses, jagged black hair, beard, gray three-button shirt, tiny legs, crisp outlines, matte surfaces and deliberate cel-shadow shapes. The rejected tall anime adult and the noisy painted v40 look are not the target.

## Implementation

- All 28 production source sheets were edited using built-in image generation against the approved character, preserving their original subjects and frame/object order. Exact prompts are retained in `ArtSources/CelV41/prompts.json`.
- The same 109 asset names replace the v40 catalog, covering 22 directional actor atlases, five outfit masks, sixteen materials and the existing furniture, fixture, equipment, prop and facade libraries. There are 264 directional actor frames.
- Existing SpriteKit scene/actor caching, tile geometry, actor anchors, interaction targets, navigation and save schemas remain unchanged. No gameplay model or collision file needs modification.
- Four-direction bodies and clothing remain aligned. Outfit masks are confined below the new larger heads so changing a shirt does not tint eye whites. The player's tool-animation arm cutouts are aligned to the approved shorter body.
- Supporting procedural props use matte cel-shadow planes instead of glossy gradients. Shared menu/button surfaces use restrained solid shading without grain; layouts, control identifiers and full hit shapes are preserved.
- The existing app icon renderer reads the new in-game player atlas. Version 41.0, build 46 identifies this candidate.

## Preservation and checks

The v40 generated sheets, prompts and manifest remain unchanged in `ArtSources/PaintedV40`. Presentation sources and icon have additional backups in `ArtBackups/v40`; the complete previous release is retained at commit `9e007d52cdcb16aeb9f5489a41929b62a1339e18`.

Validate PNG hashes/CRCs, catalog registration, atlas alpha margins, foot baselines and walking variation. Run native gameplay/save tests, the existing navigation benchmark, Release iPhone compilation and all 53 UI cases. Creative relocation/save restoration runs with the focused touch tests on the fresh simulator; the remaining 49 run afterward. Native captures include the sanctuary, home, reception, motel room, beach, neighborhood, store exteriors, bar, fish restaurant, creative layout and event actions. Review these real captures before delivering the candidate IPA.
