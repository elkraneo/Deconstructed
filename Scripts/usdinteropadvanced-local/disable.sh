#!/bin/zsh
set -euo pipefail

# Switch Deconstructed back to the public USDInteropAdvanced-binaries wrapper.

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
VERSION="${1:-0.2.15}"

patch_file() {
  local file="$1"
  python - "$file" "$VERSION" <<'PY'
import pathlib, re, sys
path = pathlib.Path(sys.argv[1])
version = sys.argv[2]
text = path.read_text()

# Replace the local path dependency with the binaries wrapper dependency.
pat = re.compile(
  r'\\.package\\(\\s*\\n\\s*path:\\s*\"/Volumes/Plutonian/_Developer/USDInteropAdvanced\"\\s*\\n\\s*\\),',
  re.M
)

repl = (
  '.package(\\n'
  '            name: \"USDInteropAdvanced\",\\n'
  '            url: \"https://github.com/Reality2713/USDInteropAdvanced-binaries\",\\n'
  '            from: \"' + version + '\"\\n'
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
echo "Disabled local source dependency. Using USDInteropAdvanced-binaries from: $VERSION"

