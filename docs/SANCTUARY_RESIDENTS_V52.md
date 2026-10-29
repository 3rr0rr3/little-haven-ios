# Sanctuary residents — v52 (57)

Three residents append to the existing eight, preserving every old numeric ID, title and pen position:

- Pink-ear Chichu: the first photo's dark hair, human face, pink kitten ears, whiskers and black shirt.
- Inferno Chichu: a pale spotted leopard with red horns, a red eye glint and small decorative flames.
- Cosmic Chichu: a green-tinted spotted leopard with dark alien eyes, antennae and a green orb.

The artwork extends the existing native cut-paper renderer, at the same 24 × 28 sprite coordinates, with front, rear, side and walking poses. Ground shadows, cached frames, existing small character scale and the original residents remain intact. Inferno's visual flames are never gameplay emergency objects.

The map extends south by ten tiles. Its original eight pens stay in place; new pens occupy rows five and six. The stairs move to the new southern end. A shared resident range drives rendering, collisions, care, dialogue, debug captures, adventures and the journal. The same camera scale follows the player through the larger room. Feed/water/bedding props and nameplates stay on their corresponding pen coordinates.

No save schema changes are required. Missing care and quest entries default through the existing dictionary lookup; old basement positions remain walkable. Model checks cover all eleven enclosed patrol routes, gate reachability, feeding cooldowns, invalid IDs, saved care, old eight-resident data and all eleven quest rewards. Native touch tests visit and care for each new resident and accept its individual quest. Release startup, prior gameplay tests and native sanctuary captures are checked before publishing the IPA.
