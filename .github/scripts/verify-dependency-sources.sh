#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${1:-.}"
COMMIT_RANGE="${2:-}"

cd "$ROOT_DIR"

echo "Checking for forbidden local package references in working tree..."

if rg -n --glob 'Package.swift' '\.package\s*\(\s*path\s*:' .; then
  echo
  echo "ERROR: Found forbidden .package(path:) dependency. Use .package(url:) or binaryTarget instead."
  exit 1
fi

python - <<'PY'
import pathlib
import re
import sys

root = pathlib.Path(".").resolve()

def check_pbxproj(name: str, text: str) -> list[str]:
    errs: list[str] = []
    for m in re.finditer(
        r"\bisa\s*=\s*XCLocalSwiftPackageReference;\s*(?:.|\n)*?\brelativePath\s*=\s*([^;]+);",
        text,
    ):
        rel = m.group(1).strip().strip('"')
        if not rel.startswith("Packages/"):
            errs.append(
                f"{name}: forbidden XCLocalSwiftPackageReference relativePath = {rel!r} (must start with 'Packages/')."
            )
    return errs

errs: list[str] = []
for p in root.rglob("*.pbxproj"):
    txt = p.read_text(encoding="utf-8", errors="replace")
    errs.extend(check_pbxproj(str(p.relative_to(root)), txt))

if errs:
    print()
    print("ERROR: Found forbidden XCLocalSwiftPackageReference outside repo (must be under Packages/...).")
    for e in errs:
        print(e)
    sys.exit(1)
PY

if [[ -n "$COMMIT_RANGE" ]]; then
  echo "Checking commit range for forbidden local package references: $COMMIT_RANGE"
  while IFS= read -r commit; do
    if git grep -n -E '\.package\s*\(\s*path\s*:' "$commit" -- ':(glob)**/Package.swift' >/dev/null; then
      echo
      echo "ERROR: Commit $commit contains forbidden .package(path:) dependency."
      git grep -n -E '\.package\s*\(\s*path\s*:' "$commit" -- ':(glob)**/Package.swift' || true
      exit 1
    fi

    COMMIT="$commit" python - <<'PY'
import os
import re
import subprocess
import sys

commit = os.environ["COMMIT"]

paths = subprocess.check_output(
    ["git", "ls-tree", "-r", "--name-only", commit],
    text=True,
).splitlines()

def check_pbxproj(name: str, text: str) -> list[str]:
    errs: list[str] = []
    for m in re.finditer(
        r"\bisa\s*=\s*XCLocalSwiftPackageReference;\s*(?:.|\n)*?\brelativePath\s*=\s*([^;]+);",
        text,
    ):
        rel = m.group(1).strip().strip('"')
        if not rel.startswith("Packages/"):
            errs.append(
                f"{name}: forbidden XCLocalSwiftPackageReference relativePath = {rel!r} (must start with 'Packages/')."
            )
    return errs

errs: list[str] = []
for p in paths:
    if not p.endswith(".pbxproj"):
        continue
    try:
        txt = subprocess.check_output(
            ["git", "show", f"{commit}:{p}"],
            text=True,
            stderr=subprocess.DEVNULL,
        )
    except subprocess.CalledProcessError:
        continue
    errs.extend(check_pbxproj(p, txt))

if errs:
    print()
    print(f"ERROR: Commit {commit} contains forbidden XCLocalSwiftPackageReference outside repo (must be under Packages/...).")
    for e in errs:
        print(e)
    sys.exit(1)
PY
  done < <(git rev-list "$COMMIT_RANGE")
fi

echo "Dependency source checks passed."

