#!/bin/zsh
set -euo pipefail

function unset_mirror() {
  local original="$1"
  echo "unset: $original"
  swift package config unset-mirror --original "$original" || true
}

unset_mirror "https://github.com/reality2713/USDInteropAdvanced"
unset_mirror "https://github.com/Reality2713/USDInterop"
unset_mirror "https://github.com/reality2713/AppleUSDSchemas"
unset_mirror "https://github.com/elkraneo/Deconstructed.git"

echo ""
echo "Mirrors removed. Current mirror status:"
./Scripts/spm-mirrors/status.sh
