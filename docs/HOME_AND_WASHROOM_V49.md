# Sanctuary, family home and guest washrooms

The sanctuary aisle uses clean, character-scale indoor tiles instead of oversized weedy outdoor stones. Enclosures retain their exact layout, rails, nameplates and creature identities, with quieter washable floor colors and light bedding texture.

Samhil uses a seated, rear-facing native pose. A cropped foreground portion of the existing sofa artwork hides the sitter's lower body behind the backrest. Family conversations can be opened by directly tapping Hildarelys or Samhil anywhere inside the home, including fullscreen with a hidden toolbar. Hildarelys pauses near the player for a stable interaction target. Reception distance rules remain unchanged.

Chichu and Chichi roam the home on the existing simulation cadence. Bounded pathfinding avoids furniture, the player, other pets and exits. Following pets keep following; a new explicit Stay here command stops roaming. Optional previous/facing/stay/homeStop fields preserve decoding of old saves. Waiting pets outside the home stay on their own maps. Cat artwork remains original.

Motel washrooms occupy the rear-right corner: tiled vanity/toilet, shower tray and a low privacy screen, with an open left approach. Shower collision tiles match their artwork. Guest patrols avoid fixtures. The TV moves to the existing lower-left furniture zone; the paint cabinet moves beside it, with a matching collision tile and interaction anchor. The center entrance remains clear. Old saved players and pets inside newly solid fixtures migrate to a safe arrival point. Cleaning, theft, painting and furnishing routes remain reachable.

Model coverage verifies roaming, furniture avoidance, follow/stay, legacy decoding, save continuity, guest routes and fixture migration. A fullscreen UI regression exercises both family conversations with the toolbar hidden. Native home, sanctuary and motel-room captures and a home-cat motion clip are preserved. The v45 MotelView startup fix remains unchanged.
