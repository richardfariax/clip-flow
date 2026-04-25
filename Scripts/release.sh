#!/usr/bin/env bash
set -euo pipefail

SCHEME="${SCHEME:-ClipVault}"
CONFIGURATION="${CONFIGURATION:-Release}"
BUILD_DIR="${BUILD_DIR:-build}"
ARCHIVE_PATH="${BUILD_DIR}/${SCHEME}.xcarchive"
APP_PATH="${ARCHIVE_PATH}/Products/Applications/${SCHEME}.app"
ZIP_PATH="${BUILD_DIR}/${SCHEME}.zip"
SHA_PATH="${BUILD_DIR}/${SCHEME}.zip.sha256"

mkdir -p "${BUILD_DIR}"
rm -rf "${ARCHIVE_PATH}" "${ZIP_PATH}" "${SHA_PATH}"

build_cmd=(
  xcodebuild
  -scheme "${SCHEME}"
  -configuration "${CONFIGURATION}"
  -archivePath "${ARCHIVE_PATH}"
  archive
)

if [[ -n "${XCODE_WORKSPACE:-}" ]]; then
  build_cmd=(
    xcodebuild
    -workspace "${XCODE_WORKSPACE}"
    -scheme "${SCHEME}"
    -configuration "${CONFIGURATION}"
    -archivePath "${ARCHIVE_PATH}"
    archive
  )
elif [[ -n "${XCODE_PROJECT:-}" ]]; then
  build_cmd=(
    xcodebuild
    -project "${XCODE_PROJECT}"
    -scheme "${SCHEME}"
    -configuration "${CONFIGURATION}"
    -archivePath "${ARCHIVE_PATH}"
    archive
  )
fi

"${build_cmd[@]}"

if [[ ! -d "${APP_PATH}" ]]; then
  echo "Erro: app não encontrado em ${APP_PATH}" >&2
  exit 1
fi

ditto -c -k --sequesterRsrc --keepParent "${APP_PATH}" "${ZIP_PATH}"
shasum -a 256 "${ZIP_PATH}" > "${SHA_PATH}"

echo "Archive gerado: ${ARCHIVE_PATH}"
echo "Pacote para GitHub Releases: ${ZIP_PATH}"
echo "Checksum SHA256: ${SHA_PATH}"
