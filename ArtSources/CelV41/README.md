# Approved compact cel-shaded art library

The user's approved small player preview is retained as approved-player-reference.png. All 28 production sheets were restyled with built-in image generation against that reference: clean contours, matte colors and deliberate cel-shadow shapes. Character identities and compact proportions remain recognizable. Materials, props, furniture, fixtures, equipment and building facades use the same treatment.

prompts.json retains each exact edit prompt and source-sheet filename; manifest.json records the 109 game resources and their SHA-256 checksums. Actor atlases remain 576 x 896 (three 192 x 224 cells per row; front, left, right, back rows; idle and two strides). Logical actor canvases, geometry and save models are unchanged.

Rebuild with Python, Pillow and NumPy:

    python scripts/pack_painted_art.py --saved-sources
    python scripts/validate_painted_art.py

Packing only slices, isolates alpha and aligns scale/baselines. It does not redraw artwork. Old v40 sheets and prompts remain unchanged in ArtSources/PaintedV40, with presentation source backups in ArtBackups/v40.
