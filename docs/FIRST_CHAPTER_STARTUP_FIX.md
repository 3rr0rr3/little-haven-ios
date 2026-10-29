# First-chapter startup investigation

The user reports an app crash after waking up to start Chapter 1 on a phone. The previous 53 UI cases began in prepared fixtures and used `--ui-testing`, so they did not exercise the actual wake-up button with normal randomized guests and automatic management initialization.

An isolated baseline diagnostic on v41 ran 20 production model startups and a real wake-button UI transition without `--ui-testing`. Both passed in the simulator. This does not reproduce or establish the exact cause of the reported device crash; device/iOS details were requested.

The camera implementation nevertheless has a concrete transition fault: it checks only the viewport width before dividing the map height by the viewport height. A transient zero-height indoor view produces infinity, which must never be assigned to the SpriteKit camera. `RPGViewport.cameraScale` now requires finite positive map/viewport dimensions and validates the resulting scale and extents. Camera layout waits for a valid view and retries on the next size/update callback. Ready-view zoom and positioning are unchanged.

Regression coverage exercises zero/negative/nonfinite viewport dimensions and normal zoom, production initializers and checkpoint round trips, and the actual wake-up button in both touch and standard controls followed by Continue after relaunch. That UI case runs on the normal simulator and a smaller iPhone SE (3rd generation), alongside the complete existing UI suite. Version 42.0 (47) retains all v41 approved art and save schemas.
