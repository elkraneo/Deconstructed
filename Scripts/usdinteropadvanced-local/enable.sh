#!/bin/zsh
set -euo pipefail

# Switch Deconstructed to build against a local USDInteropAdvanced *source* checkout.
# This is local-dev only and must not be pushed.

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
SOURCE_PATH="/Volumes/Plutonian/_Developer/USDInteropAdvanced"

if [[ ! -d "$SOURCE_PATH" ]]; then
  echo "error: missing local USDInteropAdvanced source checkout at $SOURCE_PATH" >&2
  exit 1
fi

patch_file() {
  local file="$1"
  python - "$file" "$SOURCE_PATH" <<'PY'
import pathlib, re, sys
path = pathlib.Path(sys.argv[1])
source_path = sys.argv[2]
text = path.read_text()

# Replace the binaries dependency with a local path dependency.
pat = re.compile(
  r'\\.package\\(\\s*\\n\\s*name:\\s*\"USDInteropAdvanced\"\\s*,\\s*\\n\\s*url:\\s*\"https://github\\.com/Reality2713/USDInteropAdvanced-binaries\"\\s*,\\s*\\n\\s*from:\\s*\"[^\"]+\"\\s*\\n\\s*\\),',
  re.M
)

repl = (
  '.package(\\n'
  '            path: \"' + source_path + '\"\\n'
  '        ),'
)

new_text, n = pat.subn(repl, text)
if n != 1:
  raise SystemExit(f\"Expected to patch 1 USDInteropAdvanced dependency in {path}, patched {n}.\")
path.write_text(new_text)
print(f\"Patched {path}\")
PY
}

patch_file "$ROOT_DIR/Package.swift"
patch_file "$ROOT_DIR/Packages/DeconstructedLibrary/Package.swift"

echo ""
echo "Enabled local USDInteropAdvanced source dependency."
echo "Reminder: do NOT push while this is enabled (pre-push checks will block)."

