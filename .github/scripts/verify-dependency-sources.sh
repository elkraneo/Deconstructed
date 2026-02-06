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

if rg -n --glob '*.pbxproj' 'XCLocalSwiftPackageReference' .; then
  echo
  echo "ERROR: Found forbidden XCLocalSwiftPackageReference in a .pbxproj."
  echo "Add local packages to the workspace (Deconstructed.xcworkspace), not the project."
  exit 1
fi

if [[ -n "$COMMIT_RANGE" ]]; then
  echo "Checking commit range for forbidden local package references: $COMMIT_RANGE"
  while IFS= read -r commit; do
    if git grep -n -E '\.package\s*\(\s*path\s*:' "$commit" -- ':(glob)**/Package.swift' >/dev/null; then
      echo
      echo "ERROR: Commit $commit contains forbidden .package(path:) dependency."
      git grep -n -E '\.package\s*\(\s*path\s*:' "$commit" -- ':(glob)**/Package.swift' || true
      exit 1
    fi

    if git grep -n 'XCLocalSwiftPackageReference' "$commit" -- ':(glob)**/*.pbxproj' >/dev/null; then
      echo
      echo "ERROR: Commit $commit contains forbidden XCLocalSwiftPackageReference in a .pbxproj."
      git grep -n 'XCLocalSwiftPackageReference' "$commit" -- ':(glob)**/*.pbxproj' || true
      exit 1
    fi
  done < <(git rev-list "$COMMIT_RANGE")
fi

echo "Dependency source checks passed."
