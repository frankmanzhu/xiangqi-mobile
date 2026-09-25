# App Store screenshots

Captured from the Simulator (not a physical device — Apple explicitly allows
and expects this) at the two device-size classes App Store Connect requires:

- `iphone-6.9in/` — iPhone 17 Pro Max simulator, 1320x2868px. Covers the
  required "iPhone 6.9-inch Display" slot; App Store Connect derives the
  smaller iPhone sizes from these automatically.
- `ipad-13in/` — iPad Pro 13-inch (M5) simulator, 2064x2752px. Covers the
  required "iPad 13-inch Display" slot, needed once an app supports iPad.

Each folder has the same three shots for consistency:

1. `01-home.png` — the home screen and mode picker.
2. `02-game*.png` — a live game against Pikafish.
3. `03-learning-library.png` — the offline study/puzzle library.

These are raw captures, not final marketing frames (no device bezel, caption
text, or background). Re-run through App Store Connect's screenshot editor
or a tool like Fastlane's `frameit` if you want framed/annotated versions
before upload. Regenerate any of these by booting the matching simulator,
running the app, and using `xcrun simctl io <udid> screenshot <path>`.
