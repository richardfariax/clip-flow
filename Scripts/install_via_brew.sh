#!/usr/bin/env bash
set -euo pipefail

TAP_NAME="${TAP_NAME:-richardfariax/clip-flow}"
TAP_URL="${TAP_URL:-https://github.com/richardfariax/clip-flow}"
CASK_NAME="${CASK_NAME:-clipflow}"

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew is required: https://brew.sh" >&2
  exit 1
fi

brew tap "${TAP_NAME}" "${TAP_URL}"
brew install --cask "${CASK_NAME}"

echo "ClipFlow installed via Homebrew cask."
