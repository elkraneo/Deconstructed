#!/bin/zsh
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
export DECONSTRUCTED_REPO_ROOT="$repo_root"

pbxproj="$repo_root/Deconstructed.xcodeproj/project.pbxproj"
workspace="$repo_root/Deconstructed.xcworkspace/contents.xcworkspacedata"

# Local dev mode:
# - Project references DeconstructedLibrary as a *local* SwiftPM package.
# - Workspace shows `Packages/DeconstructedLibrary` in the navigator for convenience.
#
# Do not commit the pbxproj change to main; the repo keeps `main` CI-safe.

python - <<'PY'
import os, re
from pathlib import Path

repo_root = Path(os.environ["DECONSTRUCTED_REPO_ROOT"])
pbxproj = repo_root / "Deconstructed.xcodeproj/project.pbxproj"
text = pbxproj.read_text()

UUID = "8E804A717E3CC6A7B9002921"

# Remove any existing remote or local package reference sections.
text2 = re.sub(
  r"\n/\* Begin XCRemoteSwiftPackageReference section \*/.*?/\* End XCRemoteSwiftPackageReference section \*/\n",
  "\n",
  text,
  flags=re.S,
)
text2 = re.sub(
  r"\n/\* Begin XCLocalSwiftPackageReference section \*/.*?/\* End XCLocalSwiftPackageReference section \*/\n",
  "\n",
  text2,
  flags=re.S,
)

local_section = (
  "\n/* Begin XCLocalSwiftPackageReference section */\n"
  f"\t\t{UUID} /* XCLocalSwiftPackageReference \"DeconstructedLibrary\" */ = {{\n"
  "\t\t\tisa = XCLocalSwiftPackageReference;\n"
  "\t\t\trelativePath = Packages/DeconstructedLibrary;\n"
  "\t\t};\n"
  "/* End XCLocalSwiftPackageReference section */\n"
)

# Insert before rootObject for stability.
m = re.search(r"\n\trootObject\s*=", text2)
if not m:
  raise SystemExit("Couldn't find rootObject insertion point.")
text2 = text2[:m.start()] + local_section + text2[m.start():]

# Update product dependency comments to point at the local package ref.
text2 = text2.replace(
  f"package = {UUID} /* DeconstructedLibrary (SPM) */;",
  f"package = {UUID} /* XCLocalSwiftPackageReference \"DeconstructedLibrary\" */;",
)
text2 = text2.replace(
  f"package = {UUID} /* XCRemoteSwiftPackageReference \"Deconstructed\" */;",
  f"package = {UUID} /* XCLocalSwiftPackageReference \"DeconstructedLibrary\" */;",
)

# Update the packageReferences list comment (cosmetic).
text2 = text2.replace(
  f"{UUID} /* DeconstructedLibrary (SPM) */",
  f"{UUID} /* XCLocalSwiftPackageReference \"DeconstructedLibrary\" */",
)
text2 = text2.replace(
  f"{UUID} /* XCRemoteSwiftPackageReference \"Deconstructed\" */",
  f"{UUID} /* XCLocalSwiftPackageReference \"DeconstructedLibrary\" */",
)

pbxproj.write_text(text2)
print("Updated project.pbxproj: DeconstructedLibrary is now a local package.")
PY

python - <<'PY'
import os
from pathlib import Path
import xml.etree.ElementTree as ET

repo_root = Path(os.environ["DECONSTRUCTED_REPO_ROOT"])
ws = repo_root / "Deconstructed.xcworkspace/contents.xcworkspacedata"

root = ET.fromstring(ws.read_text())
want = "group:Packages/DeconstructedLibrary"

if not any(fr.get("location") == want for fr in root.findall("FileRef")):
  fr = ET.SubElement(root, "FileRef")
  fr.set("location", want)
  # minimal formatting
  out = '<?xml version="1.0" encoding="UTF-8"?>\n' + ET.tostring(root, encoding="unicode")
  ws.write_text(out)
  print("Updated workspace: added Packages/DeconstructedLibrary.")
else:
  print("Workspace already includes Packages/DeconstructedLibrary.")
PY

echo ""
echo "Enabled local DeconstructedLibrary."
echo "Next: in Xcode, File > Packages > Reset Package Caches (once), then build."

