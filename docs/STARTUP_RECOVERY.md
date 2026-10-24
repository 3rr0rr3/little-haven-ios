# Startup recovery (v44)

The user reports that v43 still closes immediately after waking on iPhone 17 Pro Max / iOS 27.0 and cannot find an OS crash report. No cause has been confirmed. Native simulator success is not proof of a physical iOS 27 fix.

The app now writes a small local startup breadcrumb record, separate from every game/checkpoint file. It records installed version/build, iOS version and completed startup stages around model creation, world/management preparation, save writing, hotel view construction, renderer entry and office art drawing. Writes use atomic file replacement; each stage is recorded only once per attempt under a lock. No data is uploaded automatically.

An unfinished attempt opens a simple recovery screen on the next launch, before constructing ContentView or loading the game. The user can copy/share the short report inside the app, without Settings, or explicitly retry. A manual force-quit during the short startup window can also trigger this screen; it is described as an unfinished startup rather than a proven crash. A stable hotel view clears the pending marker after ten seconds. Title appearance also clears a completed launch. Game saves are never deleted or rewritten by the recovery screen.

The installed build is visible on the title screen. The hotel screen is also isolated behind AnyView boundaries to reduce the parent SwiftUI view's generic composition during the transition; this is an additional compatibility measure, not a verified root-cause fix. Existing assets, collision logic and save schemas are unchanged.

Normal Debug fixtures disable breadcrumbs so simulated test termination is not treated as a real interrupted startup. A dedicated recovery fixture verifies report display and copying without constructing gameplay. The optimized Release startup test exercises real breadcrumb lifecycle, first shift and reopening the checkpoint. A new build is a diagnostic/recovery candidate until the user confirms the physical-phone result.
