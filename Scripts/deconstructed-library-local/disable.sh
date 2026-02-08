#!/bin/zsh
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
export DECONSTRUCTED_REPO_ROOT="$repo_root"

pbxproj="$repo_root/Deconstructed.xcodeproj/project.pbxproj"
workspace="$repo_root/Deconstructed.xcworkspace/contents.xcworkspacedata"

# CI-safe mode:
# - Project references DeconstructedLibrary as a remote SwiftPM package (self-referential URL).
# - Workspace only contains the Xcode project (no local package override).

python - <<'PY'
import os, re
from pathlib import Path

repo_root = Path(os.environ["DECONSTRUCTED_REPO_ROOT"])
pbxproj = repo_root / "Deconstructed.xcodeproj/project.pbxproj"
text = pbxproj.read_text()

UUID = "8E804A717E3CC6A7B9002921"

# Remove any existing remote/local package reference sections.
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

remote_section = (
  "\n/* Begin XCRemoteSwiftPackageReference section */\n"
  f"\t\t{UUID} /* DeconstructedLibrary (SPM) */ = {{\n"
  "\t\t\tisa = XCRemoteSwiftPackageReference;\n"
  "\t\t\trepositoryURL = \"https://github.com/elkraneo/Deconstructed.git\";\n"
  "\t\t\trequirement = {\n"
  "\t\t\t\tbranch = main;\n"
  "\t\t\t\tkind = branch;\n"
  "\t\t\t};\n"
  "\t\t};\n"
  "/* End XCRemoteSwiftPackageReference section */\n"
)

m = re.search(r"\n\trootObject\s*=", text2)
if not m:
  raise SystemExit("Couldn't find rootObject insertion point.")
text2 = text2[:m.start()] + remote_section + text2[m.start():]

# Restore product dependency comments.
text2 = text2.replace(
  f"package = {UUID} /* XCLocalSwiftPackageReference \"DeconstructedLibrary\" */;",
  f"package = {UUID} /* DeconstructedLibrary (SPM) */;",
)
text2 = text2.replace(
  f"package = {UUID} /* XCRemoteSwiftPackageReference \"Deconstructed\" */;",
  f"package = {UUID} /* DeconstructedLibrary (SPM) */;",
)

text2 = text2.replace(
  f"{UUID} /* XCLocalSwiftPackageReference \"DeconstructedLibrary\" */",
  f"{UUID} /* DeconstructedLibrary (SPM) */",
)
text2 = text2.replace(
  f"{UUID} /* XCRemoteSwiftPackageReference \"Deconstructed\" */",
  f"{UUID} /* DeconstructedLibrary (SPM) */",
)

pbxproj.write_text(text2)
print("Restored project.pbxproj: DeconstructedLibrary is now a remote package.")
PY

python - <<'PY'
import os
from pathlib import Path
import xml.etree.ElementTree as ET

repo_root = Path(os.environ["DECONSTRUCTED_REPO_ROOT"])
ws = repo_root / "Deconstructed.xcworkspace/contents.xcworkspacedata"

root = ET.fromstring(ws.read_text())
want = "group:Packages/DeconstructedLibrary"

for fr in list(root.findall("FileRef")):
  if fr.get("location") == want:
    root.remove(fr)

out = '<?xml version="1.0" encoding="UTF-8"?>\n' + ET.tostring(root, encoding="unicode")
ws.write_text(out)
print("Updated workspace: removed Packages/DeconstructedLibrary.")
PY

echo ""
echo "Disabled local DeconstructedLibrary."

