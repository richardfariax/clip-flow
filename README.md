<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="ClipFlow/Resources/Assets.xcassets/ClipFlowLogoDark.imageset/logo-dark.png">
    <source media="(prefers-color-scheme: light)" srcset="ClipFlow/Resources/Assets.xcassets/ClipFlowLogoLight.imageset/logo-light.png">
    <img src="ClipFlow/Resources/Assets.xcassets/ClipFlowLogoLight.imageset/logo-light.png" alt="ClipFlow logo" width="110">
  </picture>
</p>

<h1 align="center">ClipFlow</h1>

<p align="center">
  Premium clipboard manager for macOS.<br>
  Fast, minimal, native, and built for daily professional workflows.
</p>

<p align="center">
  <a href="https://github.com/richardfariax/clip-flow/releases/latest"><img alt="Download" src="https://img.shields.io/badge/Download-macOS%20DMG-0A84FF?style=for-the-badge"></a>
  <img alt="Platform" src="https://img.shields.io/badge/platform-macOS%2014%2B-1f2937?style=for-the-badge">
  <img alt="Built with" src="https://img.shields.io/badge/SwiftUI%20%2B%20AppKit-Native-111827?style=for-the-badge">
</p>

## Why ClipFlow
ClipFlow gives you a `Windows + V` style clipboard history experience on macOS, with a polished floating panel, global hotkey access, and local-first privacy.

## Highlights
- Global hotkey to open the clipboard panel (`Option + V` by default)
- Clipboard history for text and images
- Search, favorite, pin, delete, and clear all
- Automatic paste back to the previously focused app
- Ignored app list for sensitive software (password managers, etc.)
- Optional local AES-GCM encryption
- Menu bar native app with light/dark support
- Launch at Login support

## Install (for end users)
### One-line install (no sudo, no tap)
```bash
curl -fsSL https://raw.githubusercontent.com/richardfariax/clip-flow/main/Scripts/install.sh | bash
```

This installs `ClipFlow.app` to `~/Applications` to avoid admin password prompts.

### Homebrew short command
One-time setup:

```bash
brew tap richardfariax/clip-flow https://github.com/richardfariax/clip-flow
```

Then install with the short command:

```bash
brew install --cask --appdir="$HOME/Applications" clipflow
```

### Homebrew (direct cask URL, no tap)

```bash
brew install --cask --appdir="$HOME/Applications" \
  https://raw.githubusercontent.com/richardfariax/clip-flow/main/Casks/clipflow.rb
```

Or run locally:

```bash
./Scripts/install_via_brew.sh
```

### DMG (manual)
1. Open [latest release](https://github.com/richardfariax/clip-flow/releases/latest).
2. Download `ClipFlow.dmg`.
3. Drag `ClipFlow.app` to `/Applications`.
4. Open ClipFlow and grant requested permissions.

Notes:
- If you install to `/Applications`, macOS may request admin password.
- If you install to `~/Applications`, admin password is usually not required.

## Permissions
ClipFlow may request:
- Accessibility: required for automatic paste simulation (`Cmd + V`)
- Input Monitoring: improves reliability for global hotkeys

These permission dialogs are controlled by macOS security and cannot be bypassed by the installer.

## For maintainers
Build artifacts locally:

```bash
./Scripts/release.sh
./Scripts/release_dmg.sh
```

GitHub Release automation:
- Workflow: `.github/workflows/release-assets.yml`
- Trigger: publish a Release
- Uploads: `.dmg`, `.zip`, and `.sha256` files automatically
- Homebrew cask file in this repo: `Casks/clipflow.rb`

## Privacy
ClipFlow stores data locally on your Mac.
No cloud sync is enabled by default.

## Credits
Developed by Richard Farias
- LinkedIn: https://www.linkedin.com/in/richardfariasss/
