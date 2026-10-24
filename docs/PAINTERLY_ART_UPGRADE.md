# Brainstorm Haven painted visual upgrade

## Project inspection

- Native iOS, SwiftUI menus and SpriteKit scenes (`RPGScene.swift`). No engine rewrite is needed.
- Existing art is primarily procedural Swift Canvas: `OfficeArt.swift`, `MotelArt.swift`, `TownCanvas.swift`. `Assets.xcassets` currently contains the app icon, not a reusable environment or character sprite library.
- Canvas scenery is rasterized on map/revision changes. Actors use separately cached 24 × 28 logical-point textures, four facings and stride frames. Movement interpolates SpriteKit nodes independently of background art.
- `RPGMap.swift`, `MotelWorld.swift` and `BasementLayout` in `Office.swift` define gameplay geometry. The sanctuary remains 25 × 27 tiles, eight pens at their original regions, with the same gates, routes and stairs.
- Specialized reception, house, shop and basement views in `OfficeView.swift` supply their own scenery to the shared scene renderer. All of these must be considered; changing only the generic motel renderer would miss them.
- Models and saves are Codable and do not need an art-version migration.

## Implementation plan

1. Back up existing art sources and the current icon without adding backup Swift files to the app target.
2. Generate reusable painted material and prop atlases. Slice into named asset-catalog images with a recorded cell manifest, preserving the original generated sheets and prompts.
3. Generate directional creature and player artwork from the supplied identity references. Inspect silhouettes, frame alignment and transparency before integrating. Preserve each existing Chichu name and appearance; no Pokémon replacements or reference-image logos.
4. Add a cached asset resolver to the existing drawing layer. Use material images for stone, grass, wood, walls and roofs; illustrated props for fences, lanterns, foliage and enclosure furnishings. Keep footprints independent of illustrations.
5. Rebuild sanctuary visuals from reusable components at the original logical coordinates. Keep labels as real text over wooden plates, rather than baking names or UI into a static image.
6. Apply matching materials and warm directional shading to outdoor areas, reception, home, shops and guest rooms, and consistent restrained trim to UI surfaces. Preserve working controls and menu structure.
7. Keep actor anchors and physical dimensions unchanged. Cache directional sprites and walking frames; preserve procedural working poses and outfit variants where those require compositing. Verify every rendered direction, including the back of clothes and bodies.
8. Run gameplay/save/collision and navigation checks, build the iPhone target, review sanctuary and other locations at phone scale, and run the UI regression suite before delivering a new IPA.

## Art acceptance criteria

Actual illustrated assets must supply visible brushwork and material texture. Extra code-generated rectangles, gradients or a stretched reference background do not constitute the requested illustrated redesign. Missing or unsuitable assets will be reported explicitly. Runtime generation, per-step image decoding and per-frame texture rasterization are excluded.

## Reference and provenance

Primary direction: the user's sanctuary reference attached on this request. Original player/creature identities remain authoritative. Generated assets, prompt specifications, slicing manifests and the old-art backup will be retained with the project. This is a presentation-layer change; gameplay coordinates and save fields remain intact.
