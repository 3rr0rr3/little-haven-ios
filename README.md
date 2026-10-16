# Little Haven - Motel Chapter

An original iPhone game with cut-paper cartoon characters. Begin in a cozy town, then wake up to a very different job: running a roadside motel.

## The town dream

Walk with the press-and-hold direction controls. Stand beside the seven neighbors, tap TALK, and ask for help with your cottage fund. When you collect at least 500 fictional coins, the dream fades into the wake-up scene.

Existing saves from version 1.1 keep their progress. If you already bought the cottage, the update takes you straight to the wake-up scene.

## Run your motel

- Start with rooms 101-103 and 180 coins of working capital.
- Check arriving guests into clean, empty rooms. The entire one- or two-night stay is paid at check-in.
- End the day for new arrivals and checkouts. Vacated rooms need free manual cleaning.
- Choose four wall palettes for each room and your office. Paint changes cost 25 coins.
- Upgrade each room's furnishings twice. Upgrades cost 90, then 180 coins, and each adds 30 to the nightly rate.
- Upgrade your office twice for 120, then 240 coins. Each adds 15 to every room's nightly rate and attracts another daily arrival.
- Build additional rooms, starting at 250 coins with costs rising by 150 per room. Reach nine rooms to complete the expansion goal, then continue running the business.

## Sneak into occupied rooms

Choose Sneak inside on an occupied room. Use the same hold controls to move around its interior. Approach the highlighted suitcase, watch, or camera and take it, then get back to the southern door.

Suspicion rises every second and with movement and theft. Reaching 100 percent, or moving next to the patrolling guest, triggers game over. Stolen belongings only become coins after you escape. Items cannot be collected twice during the same stay.

## Saving and game over

The town prologue saves automatically. The motel uses explicit checkpoints: tap Save at desk, or End day to save the following morning. Room visits and game-over states cannot overwrite that checkpoint.

After getting caught, choose Load last save. Your cash, guests, room upgrades, and construction return to the saved state. Closing the app also resumes from the latest checkpoint. Keep the app installed and use the same bundle identifier and signing identity when updating to preserve local saves.

## SideStore and IPA

Source URL:

https://raw.githubusercontent.com/3rr0rr3/little-haven-ios/main/sideStore.json

Download the latest successful IPA from Releases. Requires iOS 17 or later. The device build is unsigned; sign it through your sideloading tool before installing. Physical-device installation has not been verified.

GitHub Actions runs model tests, compiles the arm64 iPhoneOS app, exercises controls and motel interactions in an iPhone simulator, captures chapter previews, verifies the IPA, publishes a release, and updates the SideStore feed with its exact version and size.

## Development

Open LittleHaven.xcodeproj in Xcode, select the LittleHaven scheme and an iPhone simulator, then Run. Select your own team and signing configuration for a signed device build.

Run the platform-independent game tests on macOS:

~~~sh
swiftc LittleHaven/Game.swift LittleHaven/Motel.swift Tests/main.swift -o /tmp/little-haven-tests
/tmp/little-haven-tests
~~~

All characters, artwork and dialogue are original. No network access, advertising, accounts, or real-money purchases. All coins and theft mechanics are fictional gameplay.
