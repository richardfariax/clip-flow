#!/usr/bin/env bash
set -euo pipefail

SCHEME="ClipVault"
ARCHIVE_PATH="build/${SCHEME}.xcarchive"
EXPORT_PATH="build/export"

xcodebuild \
  -scheme "$SCHEME" \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  archive

xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportOptionsPlist ExportOptions.plist \
  -exportPath "$EXPORT_PATH"

echo "Release export concluído em: $EXPORT_PATH"
