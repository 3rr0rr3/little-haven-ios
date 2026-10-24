# iOS 27 immediate wake-up compatibility candidate

The user confirms iPhone 17 Pro Max / iOS 27.0, closing immediately after waking up. A device crash report is unavailable. The exact failure has not been reproduced: v42's normal title → Continue → wake-up → 20-second first shift → relaunch passed in an optimized Release build on an iPhone 16 Pro / iOS 18.5 simulator (run 40055552780), in both control modes. This is not a test of iOS 27.

Version 43.0 (48) provides a different reception rendering path on iOS 27 and newer. `CompatibleOfficeScene` composes the same `ExpandedOfficeArt`, original actor artwork, walking frames, work poses, check-in effects and celebration decoration directly with SwiftUI. It creates neither an SKView nor ImageRenderer-generated office textures. The existing `OfficeReceptionView` keeps all touch targets, collision logic, booking, management, menus and saves. Approved asset bytes and character sizes are unchanged. Other maps retain their existing SpriteKit renderer.

For the SpriteKit maps, view setup now waits for positive finite laid-out bounds and a window. The coordinator coalesces the latest scene update on the next main-loop turn, rather than invoking ImageRenderer recursively during SwiftUI's `updateUIView`. Removal cancels pending work, and temporary render objects are drained after configuration. The finite camera guard remains.

The wake button prepares the world and management state before showing the office, and uses a transaction without the wake screen's animation. Existing initialization remains idempotent and the save schema is unchanged.

CI explicitly forces the same reception compatibility branch on the available older simulator. Added UI cases cover real production wake-up in standard/touch modes, checkpoint reopening and a guest booking with unchanged hit targets. An optimized Release case is compiled only in Release and run after a host-only simulator seeder writes the pre-wake checkpoint and compatibility preference. It waits 20 seconds in the office and reopens the saved first shift. Normal Debug fixture launches clear the forced preference so existing native-renderer tests stay independent.

This is a targeted compatibility workaround, not a verified diagnosis of an iOS 27 system bug. It still requires confirmation on the user's phone. No new artwork, save reset, main merge or SideStore feed change is part of this candidate.
