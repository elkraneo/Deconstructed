#!/bin/zsh
set -euo pipefail

# SwiftPM mirrors let you keep `.package(url: ...)` in git (CI-safe),
# while locally routing specific dependencies to checked-out folders.
#
# Mirrors are per-user (stored under ~/.swiftpm), not in the repo.

function set_mirror() {
  local original="$1"
  local local_path="$2"

  if [[ ! -d "$local_path" ]]; then
    echo "skip: $original (missing $local_path)"
    return 0
  fi

  # SwiftPM expects a URL; use a file:// URL for local folders.
  local mirror="file://${local_path}"
  echo "set:  $original -> $mirror"
  swift package config set-mirror --original "$original" --mirror "$mirror"
}

# USDInterop and AppleUSDSchemas are source dependencies and are safe to mirror.
set_mirror "https://github.com/Reality2713/USDInterop" "/Volumes/Plutonian/_Developer/USDInterop"
set_mirror "https://github.com/reality2713/AppleUSDSchemas" "/Volumes/Plutonian/_Developer/AppleUSDSchemas"

# Some tooling resolves mirrors by package identity rather than URL. Set both.
set_mirror "usdinterop" "/Volumes/Plutonian/_Developer/USDInterop"

echo ""
echo "Mirrors installed. Current mirror status:"
./Scripts/spm-mirrors/status.sh

