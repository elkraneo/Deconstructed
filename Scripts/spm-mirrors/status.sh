#!/bin/zsh
set -euo pipefail

function show_mirror() {
  local original="$1"
  local result
  result="$(swift package config get-mirror --original "$original" 2>/dev/null || true)"
  if [[ -z "$result" ]]; then
    echo "none: $original"
  else
    echo "have: $original -> $result"
  fi
}

show_mirror "https://github.com/Reality2713/USDInterop"
show_mirror "https://github.com/reality2713/AppleUSDSchemas"
show_mirror "https://github.com/Reality2713/USDInteropAdvanced-binaries"
show_mirror "usdinterop"
show_mirror "usdinteropadvanced-binaries"
