# Little Haven - Family Reception

An original iPhone RPG with cut-paper cartoon characters, a town dream, and a motel you run by walking around its grounds and interiors.

## Start the shift

Complete the town's 500-coin cottage fund to wake up in your motel office. Existing cottage owners see the wake-up scene, and existing version 2.0 motel saves keep their cash, rooms and upgrades.

Use the movement stick to walk in eight directions, or press and hold the arrow controls. The camera follows your character outdoors. Buildings, cars, water, people and furniture block your path.

## Work in the world

There is no motel management dashboard. Walk to a person or object and use the context action button.

- Office door: walk through to enter or leave the office.
- Waiting clients outside reception: talk, choose a clean empty room, collect payment, and hand over a key. Guests then walk to their rooms.
- Room doors: enter empty rooms to work inside. Enter occupied rooms quietly to sneak.
- Office tools closet: collect your mop, fresh sheets and bin bags.
- Dirty rooms: stand beside the unmade bed, trash and floor spill. Hold the work button for each task. Only a fully serviced room can be rented again.
- Paint cabinets inside rooms and the office: choose a wall color for 25 coins.
- Beds in guest rooms: upgrade furnishings, increasing the nightly rate.
- Front desk: upgrade the office or save your checkpoint.
- Office logbook: save your checkpoint.
- Office bed: sleep until morning, advance stays, handle checkouts and save. Departing clients walk toward the road.
- Build sign or next construction plot: build another physical room. Grow from three rooms to nine.
- Map button: inspect the property layout and instructions without teleporting.

Guests pay for their full one- or two-night stay at check-in. Room furniture upgrades add 30 to that room's nightly rate; office upgrades add 15 to all rooms' nightly rates and attract extra arrivals. Cleaning supplies are free, so an empty wallet cannot prevent you from preparing rooms.

## Sneaking

Occupied rooms have highlighted belongings. Move beside them to take them, keep away from the guest, and return to the lower exit. Suspicion rises with time, movement and theft. Reaching 100 percent or getting too close to the guest means game over. Stolen items become money only after you escape.

## Checkpoints

The town saves automatically. In the motel, save at the office desk or logbook, or sleep to save the next morning. Cleaning progress, tools, room colors, upgrades, client stays and your position are saved. Room visits and game over never overwrite your safe checkpoint.

If caught, load your last save. Changes made since that checkpoint are lost. Closing the app also resumes from the last saved checkpoint.

## SideStore / IPA

Source: https://raw.githubusercontent.com/3rr0rr3/little-haven-ios/main/sideStore.json

Download the latest successful build from Releases, or refresh the existing SideStore source. Requires iOS 17 or later. The IPA is an unsigned arm64 iPhoneOS build; your sideloading tool signs it for installation. Physical-device installation has not been verified.

## Development

Open LittleHaven.xcodeproj in Xcode and choose an iPhone simulator. For a signed device build, use your own signing configuration.

Run game-rule tests on macOS:

~~~sh
swiftc LittleHaven/Management.swift LittleHaven/Office.swift LittleHaven/RPGMap.swift LittleHaven/Game.swift LittleHaven/Motel.swift LittleHaven/MotelWorld.swift Tests/main.swift -o /tmp/little-haven-tests
/tmp/little-haven-tests
~~~

GitHub Actions runs game-rule tests, simulator tests for walking, payments, cleaning, customization, construction and checkpoint recovery, builds and verifies the IPA, captures chapter screenshots, publishes a release, and refreshes the SideStore feed.

All characters, artwork and dialogue are original. There are no ads, accounts, network access, or real-money purchases in the app. All coins and theft mechanics are fictional gameplay.

## Native RPG engine

Version 3.2 restores the original cut-paper characters and scenery from 3.0. The playable town, cottage, motel grounds, office and rooms now run in SpriteKit scenes. Independent actor nodes have cached directional artwork, walk cycles, depth ordering, and a following camera. Scenery is cached per map revision rather than redrawn every frame. SwiftUI provides the touch controls and dialogs.

RPGMap.swift defines serializable map boundaries, collision regions, passages, object events and map transfer metadata. These definitions drive game collision and office event dispatch. RPGScene.swift presents the maps and actors. Existing Codable game models remain authoritative for payments, cleaning, stealth and checkpoints, preserving save compatibility.

This is a custom iPhone-native RPG foundation using Apple's SpriteKit. It is not RPG Maker, Pok�mon Essentials, or compatible with their project files. No proprietary RPG Maker runtime is included.
## Family reception (4.0)

The expanded 15-by-15 office is operated from a fixed position behind the desk. Clients walk through the entrance one at a time, introduce themselves and request a stay. Choose a clean room to accept and collect payment, or politely decline. Visitors walk back through the door and continue to their assigned room or the road. Tap the lower office door to resume free walking on the grounds. Returning to the office puts you behind the desk again.

Tap the gray tabby Chichu or calico Chichi to pet them or offer a treat. Samhil sits on the couch watching TV, and Hildarelys walks around the office. Tap either to chat. The owner has dark spiky hair, rectangular glasses, a beard and a light collared shirt; Hildarelys has long dark hair, red lipstick and a black-and-white outfit. Artwork is an original cut-paper cartoon interpretation of the provided references. Original photos are not bundled or published.

Tap the desk or logbook to save, the closet to collect cleaning tools, the paint shelf to redecorate, and the bed to end the day. Existing saves retain motel cash, rooms, upgrades and quests. Older office positions migrate to the desk. Reception visitors and their decisions are included in checkpoints.
## Motel mayhem (5.0)

Guests leave one-to-five-star reviews when they check out. Upgraded rooms improve reviews; unresolved outdoor emergencies and stolen belongings hurt them. Open the review board from the HUD or desk. Reviews, staff, payroll status, incidents and guest complaints are saved with your checkpoint.

From the desk, hire Luna (housekeeper, 100 coins, 15/day), Mateo (groundskeeper, 140 coins, 20/day), and Riley (security, 160 coins, 25/day). Their first shift is included. Each morning, wages are deducted if affordable; otherwise that employee takes the shift off. Staff walk through the grounds: Luna services vacant dirty rooms, Mateo responds to fires and pool accidents, and Riley handles fights. Room upgrades are available from the desk as well as inside vacant rooms.

When guests are staying, incidents periodically occur outside: a courtyard fire, a guest falling in the pool, or a fight near reception. Follow the persistent alarm, walk to the scene and use HELP to intervene, or let matching hired staff respond. Incidents have a 90-second active-play deadline; ignored events cost up to 40 coins and can produce bad reviews. Dialogue and management panels pause simulation time. Office reception and the family remain unchanged.

Character conversations and game decisions now appear as portrait dialogue boxes within the scene, rather than system iPhone alerts.