#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${1:-.}"

cd "$ROOT_DIR"

echo "Checking public USD boundary..."

forbidden_source_patterns=(
  '^[[:space:]]*import[[:space:]]+USDTools\b'
  '^[[:space:]]*import[[:space:]]+USDTools[A-Za-z0-9_]*\b'
  '^[[:space:]]*import[[:space:]]+USDInteropAdvanced\b'
  '^[[:space:]]*import[[:space:]]+USDInteropAdvanced[A-Za-z0-9_]*\b'
)

for pattern in "${forbidden_source_patterns[@]}"; do
  if rg -n --pcre2 "$pattern" \
    Package.swift \
    Packages/DeconstructedLibrary/Package.swift \
    Packages/DeconstructedLibrary/Sources \
    Deconstructed.xcodeproj/project.pbxproj >/dev/null; then
    echo
    echo "ERROR: Public Deconstructed build path references a private USD module."
    rg -n --pcre2 "$pattern" \
      Package.swift \
      Packages/DeconstructedLibrary/Package.swift \
      Packages/DeconstructedLibrary/Sources \
      Deconstructed.xcodeproj/project.pbxproj || true
    exit 1
  fi
done

echo "Public USD boundary check passed."
