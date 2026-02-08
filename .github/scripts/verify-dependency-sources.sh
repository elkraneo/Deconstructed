#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${1:-.}"
COMMIT_RANGE="${2:-}"

cd "$ROOT_DIR"

echo "Dependency source checks (pre-push)..."

if [[ -n "$COMMIT_RANGE" ]]; then
  echo "Checking commit range for forbidden local package references: $COMMIT_RANGE"
  while IFS= read -r commit; do
    if git grep -n -E '\.package\s*\(\s*path\s*:' "$commit" -- ':(glob)**/Package.swift' >/dev/null; then
      echo
      echo "ERROR: Commit $commit contains forbidden .package(path:) dependency."
      git grep -n -E '\.package\s*\(\s*path\s*:' "$commit" -- ':(glob)**/Package.swift' || true
      exit 1
    fi

    # Local DeconstructedLibrary is part of this repo, and we want Xcode to treat it
    # as a local package (no remote self-dependency). That's safe to commit.
    # However, we still forbid adding arbitrary local package references.
    if git grep -n 'XCLocalSwiftPackageReference' "$commit" -- ':(glob)**/*.pbxproj' >/dev/null; then
      pbx="$(git show "$commit:Deconstructed.xcodeproj/project.pbxproj" 2>/dev/null || true)"
      local_count="$(printf '%s' "$pbx" | grep -c 'isa = XCLocalSwiftPackageReference;' || true)"
      allowed_count="$(printf '%s' "$pbx" | grep -c 'relativePath = Packages/DeconstructedLibrary;' || true)"
      if [[ "$local_count" != "1" || "$allowed_count" != "1" ]]; then
        echo
        echo "ERROR: Commit $commit contains forbidden XCLocalSwiftPackageReference in a .pbxproj."
        git grep -n 'XCLocalSwiftPackageReference' "$commit" -- ':(glob)**/*.pbxproj' || true
        exit 1
      fi
    fi
  done < <(git rev-list "$COMMIT_RANGE")
fi

echo "Dependency source checks passed."
