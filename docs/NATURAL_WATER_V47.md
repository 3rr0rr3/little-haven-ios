# Natural water and proportional paths

Replaces the oversized weed-filled path atlas in shared outdoor paving with world-aligned, character-scale stone courses. Changes are presentation-only: tile coordinates, collision regions, creative structure anchors, saves, characters and gameplay remain unchanged.

Pool water uses a calm turquoise depth gradient. Ocean water deepens away from the existing shore. The static shore path is shared with clipped moving foam; it does not change the logical beach boundary. The old repeated bright caustic web texture is no longer drawn on either surface.

SpriteKit owns 12 pool ripples, 36 ocean ripples and three shore foam curves, built once on map/creative pool relocation changes. Native node actions animate position, scale and opacity; they do not rerasterize the map or trigger SwiftUI updates each frame. Masks keep water effects in the water. Moving the pool in creative mode moves its animated surface. Reduce Motion keeps a quiet stationary surface. No new raster assets were generated.

Native capture includes a quiet pool view, beach view and an eight-second beach motion video. The existing release wake/save checks and gameplay regression checks gate the candidate IPA.
