# Painted art library

The 28 selected generated sheets and exact prompts are retained here, alongside earlier art iterations. `manifest.json` records the 109 packed game resources, source bounds, dimensions and SHA-256 checksums. These source sheets are outside the app's resources; only the packed asset catalog is shipped.

Actors use a 576 × 896 atlas: three 192 × 224 cells per row, four rows. Rows are front, left, right, back. Columns are idle and alternating walking poses. The common foot baseline is pixel 218. The existing game still renders actors on its 24 × 28 logical canvas with unchanged collision footprints.

Repack from a clean checkout with Python, Pillow and NumPy:

```
python scripts/pack_painted_art.py --saved-sources
python scripts/validate_painted_art.py
```

Packing performs alpha cleanup, component isolation, slicing and scale/baseline alignment. It does not generate or repaint artwork. The original sheets were created with the built-in image generation tool. The older procedural artwork remains in `ArtBackups/v39`.

`LittleHaven/PaintedArt.swift` caches image and frame decoding. Scenery continues to be rasterized by the existing SpriteKit map/revision cache. Geometry and save models do not depend on the art. Labels remain real text, and the supplied reference is not stretched into a gameplay background.
