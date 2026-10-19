Little Haven 13.0 (17) — separate family home and open neighborhood

- Restored the open reception office and moved Hildarelys, Samhil, Chichu and Chichi into a separate family house east of the motel. Their original designs, walking/cat animations and interactions are retained.
- Added a pitched roof, chimney, porch, garden and distinct home interior. Visit at column 54, row 14. The house has a marked checkpoint and a decoration menu.
- Spend motel profits on three home upgrades: unlock the west room, expand furnishing capacity and renovate the exterior. Customize walls and floors.
- Willow Home sells plants, rugs, lamps, bookshelves, tables and armchairs. Purchases enter home storage; place items on the home grid, return them to storage and reposition them. Placement preserves family paths and the exit.
- Expanded the grounds to a connected 72 × 48 neighborhood with roads, storefronts and seven animated pedestrians who move between destinations and flee nearby emergencies.
- Thread & Co. sells and equips outfits. Owned clothing can be worn again without another charge.
- Second Chance Pawn buys carried stolen belongings individually. Escaping with loot adds items to inventory and never awards cash; payment happens only when selling at the pawn shop.
- Fires and fights rotate through reachable locations across the motel and neighborhood. Animations, manual intervention, evacuation and employee responses share the actual incident position. Pool incidents remain at the pool.
- Home upgrades, finishes, furniture, wardrobe, carried belongings and neighborhood movement are included in checkpoints. Existing motel saves migrate through optional fields.

Verified: portable rules on Linux and native model rules on macOS passed, including physical shop access, home renovation, decoration placement, outfit ownership, explicit pawn sales, saved inventory and legacy saves. All 22 iPhone simulator UI tests passed with zero failures. Release iPhoneOS compilation, arm64/platform/archive checks and preview capture passed. Downloaded IPA matched its published SHA256; its Info.plist reports version 13.0, build 17 and iPhoneOS, and its executable is arm64. Family-home, neighborhood and restored-office captures were visually reviewed. SideStore feed was verified at 13.0 (17). Physical-device installation has not been tested.
IPA: https://github.com/3rr0rr3/little-haven-ios/releases/download/sideload-47-1/LittleHaven-unsigned.ipa
Release: https://github.com/3rr0rr3/little-haven-ios/releases/tag/sideload-47-1
Workflow: https://github.com/3rr0rr3/little-haven-ios/actions/runs/39283779421
SHA256: 06db66d5bdce771879362ed274f10bf89a22eaea026ec74cc0d80d84dcf7b51a

Previous release:
Little Haven 12.0 (16) — sideload-43-1 family room and continuous staff work

- Hildarelys, Samhil, Chichu and Chichi now occupy a separate room inside the office, with a partition, walkable doorway, television, couch, cat beds and bowls. Their character designs, animation routes and existing interactions remain supported.
- Removed the shared staff break pavilion. Nora uses reception, Luna housekeeping by the laundry, Mateo maintenance by the pool pump, Riley the security post and Diego the car wash. Idle and off-shift employees return to their own posts.
- Emergency movement and staff navigation update every 0.18 seconds independently of the business clock. Walk cycles continue between movement updates and update facing at turns, eliminating the former step/wait/step cadence.
- Staff no longer wait for the business-clock speed filter before moving. They can approach a job from a neighboring tile if the player occupies its destination. Fatigue slows clerks without permanently preventing work.
- Maintenance and security travel to assignments before working. Housekeeping, repairs, complaint handling and paid car washes complete actual model tasks. Staff statuses identify jobs and missing water, stock or funds; restocking resumes work.
- Work progress, emergency countdowns, parking arrivals, wages and paid services retain their own business cadence. Faster navigation cannot duplicate car-wash income or accelerate emergency resolution.
- Existing checkpoints migrate through optional worker fields and relocate a saved player off the new partition if necessary.

Verified: native model tests including family-room reachability, individual work posts, continuous staff navigation, occupied job destinations, independent clocks, tired-clerk recovery and actual housekeeping/maintenance/security/car-wash completion. All 19 iPhone simulator UI tests passed with zero failures. Release iPhoneOS compilation, arm64/platform/archive checks and generated previews passed. Downloaded IPA matched its published SHA256. Physical-device installation has not been tested.
IPA: https://github.com/3rr0rr3/little-haven-ios/releases/download/sideload-43-1/LittleHaven-unsigned.ipa
Release: https://github.com/3rr0rr3/little-haven-ios/releases/tag/sideload-43-1
Workflow: https://github.com/3rr0rr3/little-haven-ios/actions/runs/39259345255
SHA256: ebc9bd4ce39beb26c53651661b40b71ba114f1e5bc149e567651f7128be25e81

Previous release:
Little Haven 11.0 (15) — sideload-42-1 responsive controls and expressive guests

- D-pad arrows deliver touch-down directly and start the first step immediately; release, cancellation or leaving the button stops walking. Player walk textures are prepared before movement.
- Your original player character appears in the title courtyard with a subtle idle animation.
- Idle and off-shift employees walk to the new staff break pavilion, with individual seats and a coffee table; available employees return to their jobs and emergencies when needed.
- Pool emergencies animate the actual guest's skin, hair, clothing, accessories and face, with waving arms, bobbing and splashes. Event participants persist in checkpoints and are absent from their rooms during the emergency.
- Guests have varied facial expressions. Fear, anger, concern and determination accompany emergencies and staff interventions. Bystanders and special visitors flee using routes that avoid danger, then return when the event ends.
- Sedans, SUVs and pickups have distinct body details, windows, wheels, lamps, mirrors, handles, roof rails and pickup beds.
- NPC hat designs use brims or visors, with no beanies.
- Options, quit confirmation and the goodbye screen now use the game's green, cream and gold palette, bordered panels and motel-style controls.

Verified: native model tests including staff breaks, evacuation/recovery and guest identity; all 19 iPhone simulator UI tests with zero failures; Release iPhoneOS compilation; arm64/platform/archive checks; title, options, quit, parking and staff emergency previews. Downloaded IPA SHA256 matched the published checksum. Physical-device installation has not been tested.
IPA: https://github.com/3rr0rr3/little-haven-ios/releases/download/sideload-42-1/LittleHaven-unsigned.ipa
Release: https://github.com/3rr0rr3/little-haven-ios/releases/tag/sideload-42-1
Workflow: https://github.com/3rr0rr3/little-haven-ios/actions/runs/39235382334
SHA256: 0f7974d6775b8f352491b54d022e196ed1020533c872b4e3c374f19853643143

Previous release:
Little Haven 10.0 (14) — sideload-37-1 start menu and movement

- Courtyard title screen inspired by the supplied reference, with Continue/Start Game, New Game, Options and Quit.
- New Game confirms before replacing the saved adventure and restores the initial zero-coin town state. Continue loads the last checkpoint. Save & return to title is available from pause and the town journal.
- Options persist on this device: gameplay hints, action haptics and larger D-pad buttons; restore defaults and controls help are included.
- The player can walk around the office with collision, facing and walk animation. Reception ticks no longer teleport the player to the desk, and guests wait to be tapped before opening a conversation.
- Releasing or canceling the D-pad, leaving a direction button, backgrounding the app, or changing maps immediately stops movement. Outdoor service controls reserve a fixed area, so approaching luggage, car wash and other tasks cannot move the D-pad.
- Existing hotel management, weather, emergencies, staff, parking and checkpoint systems remain supported.

Verified: native model tests, all 18 iPhone simulator UI tests, Release iPhoneOS compilation, arm64/platform/archive checks and generated previews. Physical-device installation has not been tested.
IPA: https://github.com/3rr0rr3/little-haven-ios/releases/download/sideload-37-1/LittleHaven-unsigned.ipa
Workflow: https://github.com/3rr0rr3/little-haven-ios/actions/runs/39188096689

Previous release:
Little Haven 9.0 (13) — sideload-30-1 hotel management

- Day/night shifts, more frequent night problems, rent, utilities, payroll, supplies and debt.
- Basic, deluxe, suite and hourly rooms with cleanliness, wear, faults and functional upgrades; nightly, hourly and weekly contracts, pricing and reservations.
- Distinct recurring guests, needs, reviews, relationships and special visitors. Staff profiles, training, fatigue, honesty, night coverage and quitting.
- Fourteen complaint/event types with safe responses, optional shady offers, police citations and animated scene effects. Existing drowning, fights, fire, weather, outdoor services, theft and car washing remain playable.
- Land and floor expansion to eighteen rooms; pool, restaurant, parking, CCTV/night vision and local economic conditions.
- Cleaning/repair timing mini-games and ethical, greedy, criminal and cult story outcomes. Existing saves migrate through optional simulation state.

Open MANAGE in the hotel HUD. See docs/MANAGEMENT.md for controls and costs.

Verified: native model tests, all 15 iPhone simulator UI tests, Release iPhoneOS compilation, arm64/platform/archive checks and generated previews. Physical-device installation has not been tested.
Workflow: https://github.com/3rr0rr3/little-haven-ios/actions/runs/39169870244

Previous release:
Little Haven 8.0 (12) — sideload-26-1

- Animated drowning with waving arms, bobbing head and splashes; alternating angry punches and recoil; flickering fire, sparks and rising smoke.
- Three guest parking bays with arriving cars. Hire Diego (120 coins; 18/day) to walk to cars and wash them for 35 coins each. Manual washing is available at the bays. Each car pays once per day, including across save reloads.
- Visible sheets, trash bags, mop strokes, foam, spray, laundry, watering, breakfast, luggage, paint rollers, repair tools and construction effects.
- Recognizable suitcase, watch and camera designs on room furniture. Theft animates each object from its source to the player's hands.
- Automatically changing outdoor sun, rain, thunderstorm, wind and snow. Weather stays outside; storm shading and lightning accompany rain.
- New fields are optional to preserve existing saves.

Verified: native model tests, all 12 iPhone simulator tests, Release iPhoneOS compilation, arm64/platform/archive checks, and generated screenshots and three emergency videos. Physical-device installation has not been tested.
IPA: https://github.com/3rr0rr3/little-haven-ios/releases/download/sideload-26-1/LittleHaven-unsigned.ipa
Workflow: https://github.com/3rr0rr3/little-haven-ios/actions/runs/39083763244

