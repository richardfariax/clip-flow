# ClipFlow

ClipFlow is a native macOS clipboard history app (menu bar + global hotkey), built with Swift, SwiftUI, AppKit, NSPasteboard, and SwiftData.

## What it does
- Monitors clipboard changes in background.
- Stores text and images locally.
- Supports search, favorites, pin to top, delete, and clear all.
- Opens a floating panel with global hotkey (`Option + V` by default).
- Pastes selected item back to the previously focused app.
- Supports Launch at Login.
- Supports ignored apps list (password managers, etc).
- Optional local AES-GCM encryption.
- Manual distribution via GitHub Releases (`.dmg` / `.zip`).

## Requirements
- macOS 14+
- Xcode 15+

## Project structure
- `ClipFlow/` app source code
- `ClipFlowTests/` unit tests
- `Scripts/release.sh` release zip builder
- `Scripts/release_dmg.sh` release dmg builder
- `ClipFlow.xcodeproj` and `ClipFlow.xcworkspace`

## Bundle identifier
- `com.richadfarias.clipflow`

## Run locally
```bash
xcodebuild -project ClipFlow.xcodeproj -scheme ClipFlow -destination 'platform=macOS' build
```

Or open `ClipFlow.xcodeproj` in Xcode and run.

## Permissions
ClipFlow may need:
- Accessibility (automatic paste via Cmd+V simulation)
- Input Monitoring (best reliability for global hotkey behavior)

Tip: for stable permission behavior, test with an app installed in `/Applications` (from DMG), not only from Xcode DerivedData.

## Build release artifacts
```bash
./Scripts/release.sh
./Scripts/release_dmg.sh
```

Artifacts are generated in `build/`.

## Distribution
1. Upload `build/ClipFlow.dmg` (or `build/ClipFlow.zip`) to GitHub Releases.
2. Share checksum file (`.sha256`) with the release.
3. User installs by dragging `ClipFlow.app` to `/Applications`.
