# Little Haven

A small, original pixel-style town RPG for iPhone. Arrive in Willow Town with no coins, ask seven neighbors for help, and buy a cottage of your own.

## Play

- Use the direction buttons to explore. The camera follows you.
- Stand next to a neighbor and tap **TALK**, then ask for help buying a house.
- Each neighbor contributes once. Together they offer 545 fictional coins.
- The blue-roof cottage in the northeast costs 500 coins. Stand at its entrance and tap **COTTAGE** to purchase it.
- After buying it, tap **ENTER** to visit your furnished home. Walk through the southern door to leave.
- The journal tracks contributions and offers a confirmed new-game reset. Progress saves automatically on your device.

All characters, map art, and dialogue are original, drawn directly with SwiftUI Canvas. Inspired by the feel of classic handheld town RPGs; no Pokemon assets, trademarks, music, or game data are included. No network access, advertising, accounts, purchases, or real-money donations.

## iPhone IPA

Download `LittleHaven-unsigned.ipa` from this repository's Releases. Requires iOS 17 or later. This is an **unsigned device build**: it must be signed using an Apple account or valid signing certificate through a compatible sideloading tool before installation. It cannot be installed by simply tapping the file. Device installation is not verified by CI.

Every push to main runs game logic tests, compiles the iPhone app, verifies the arm64 iPhoneOS executable, and publishes an IPA and SHA-256 checksum in a prerelease. GitHub's macOS runner provides Xcode; no Apple signing credentials are stored in this repository.

## Development

Open `LittleHaven.xcodeproj` in Xcode, choose the `LittleHaven` scheme and an iPhone simulator, then Run. For a signed physical-device build, select your own development team and a unique bundle identifier in Signing & Capabilities.

Run the platform-independent logic checks on macOS:

```sh
swiftc LittleHaven/Game.swift Tests/main.swift -o /tmp/little-haven-tests
/tmp/little-haven-tests
```

The game is a compact, complete first adventure, with exploration and dialogue rather than combat. Saves use local UserDefaults; deleting the app may delete progress.
