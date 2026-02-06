# RCP Transform Phase Notes (Deconstructed)

Date: 2026-02-06

This document captures what we learned and implemented in the "Transform inspector + live viewport updates" phase, with an emphasis on Reality Composer Pro (RCP) parity and CI safety.

## Goals For This Phase

- Make the Transform inspector writable (not read-only).
- Persist edits to USD in an RCP-compatible way.
- Make viewport updates feel "live" (no full reload, preserve camera).
- Keep Deconstructed CI-safe and consistent with our dependency policy:
  - No `.package(path:)` committed.
  - No `XCLocalSwiftPackageReference` committed in `.pbxproj`.
  - Advanced USD operations must go through `USDInteropAdvanced` with typed DTOs in `USDInterfaces`.

## Key Confirmation: Where RCP Stores Transforms

We verified that the RCP reference project authors transforms directly in USD using `xformOp` ops.

Reference file:

- `/Volumes/Plutonian/_Developer/Deconstructed/references/Base/Sources/Base/Base.rkassets/Scene.usda`

Example evidence from the file:

- `xformOp:translate`
- `xformOp:orient`
- `xformOp:scale`
- `xformOpOrder = ["xformOp:translate", "xformOp:orient", "xformOp:scale"]`

Implication:

- Our Transform inspector should edit USD transforms (layer-authored `xformOp` ops), not store transforms in `.realitycomposerpro` metadata as a separate “component”.

## What `.realitycomposerpro` Metadata Gives Us (and What It Doesn’t)

RCP’s `main.json` is a loose index that maps *scene file paths* to UUIDs:

- `/Volumes/Plutonian/_Developer/Deconstructed/references/Base/Package.realitycomposerpro/ProjectData/main.json`

Important:

- This does **not** provide stable prim IDs / prim UUIDs.
- It is helpful for document-level scene identity, not for per-prim selection resolution.

## USD Editing Architecture Policy (Integration Boundary)

We enforce the following policy:

- `USDInteropAdvanced` is the integration boundary for advanced USD operations.
- Deconstructed features must not do raw OpenUSD/SwiftUsd “VtValue plumbing”.
- Shared DTOs used across repos live in `USDInterfaces` (in `USDInterop`), e.g. `USDTransformData`.
- Deconstructed calls typed APIs on `USDAdvancedClient` (e.g. `setPrimTransform`) instead of duplicating low-level logic.

This keeps the app code stable and testable while allowing the USD layer to evolve without rewriting UI/features.

## Writable Transform Inspector: What We Implemented

We wired Transform edits end-to-end:

1. Inspector edits produce a typed value (`USDTransformData`).
2. Deconstructed calls `USDAdvancedClient.setPrimTransform(url:path:transform:)` (from `USDInteropAdvanced`).
3. `USDInteropAdvanced` authors the transform via `UsdGeomXformCommonAPI` and saves the root layer.

Key types:

- `USDTransformData` (DTO, lives in `USDInterfaces`).
- `USDAdvancedClient.setPrimTransform` (typed editing API, lives in `USDInteropAdvancedEditing`).

## Viewport Refresh: Why Full Reload Felt Wrong

Initial behavior:

- After a transform edit we re-imported the entire model asset.
- This caused blanking/tearing, camera restore weirdness, and a “hard refresh” feel.

Observed RCP behavior:

- RCP updates the live scene graph: it can apply xform ops to the selected prim without re-importing everything.
- Camera stays stable while the object visibly moves.

Conclusion:

- If we want RCP parity, we should apply transforms directly to the live rendered `Entity` immediately, and treat USD as the canonical persistence layer (write-through or write-on-commit).

## Implemented: Live Transform Application (No Reload)

We now do both:

- Apply transform immediately to the currently rendered `Entity` (best-effort mapping).
- Persist the transform to USD using `USDInteropAdvanced`.

This yields:

- Immediate feedback in the viewport.
- Stable camera.
- Correct persistence on disk.

### The Hard Part: Prim Path ↔ RealityKit Entity Mapping

RealityKit’s USD importer does not expose a public “prim path” on imported entities. Public APIs mainly give us:

- `Entity.name` (often a leaf name)
- hierarchy and components that are not guaranteed to reflect USD metadata

So we built best-effort mapping:

1. If a prim leaf name is unique in the USD scene graph, map that leaf name to a single prim path.
2. Traverse imported entity hierarchy and tag entities that match unique leaf names.
3. For ambiguous names, attempt structural disambiguation by matching ancestor-name chains against prim path structure (ignoring wrapper nodes).
4. Once resolved, attach a custom component so future edits are stable.

This is intentionally scoped as best-effort because it is constrained by public APIs.

## RealityKit vs Hydra (Notes)

We have evidence that RCP uses RealityKit for its viewport rendering in at least some cases.

RealityKit importer limitations we observed in practice:

- Instancing and materials can behave differently than Hydra.
- Missing textures may show as magenta/pink (common when material binding/import is incomplete or unsupported).

Finder Preview appears to use a Hydra-like pipeline for USD previews, which can differ from RealityKit behavior.

Implication:

- Even if Hydra would provide “truer” USD semantics for some assets, matching RCP likely requires continuing with RealityKit (and handling its limitations explicitly).

## CI Safety: Dependency Source Guardrails

We enforce and maintain:

- No `.package(path:)` in committed `Package.swift` files.
- No `XCLocalSwiftPackageReference` in committed `.pbxproj` files.

The Xcode app uses a workspace:

- `/Volumes/Plutonian/_Developer/Deconstructed/source/Deconstructed/Deconstructed.xcworkspace`

Local packages belong in the workspace (not the project) and must not be committed as local references in `.pbxproj`.

### Validation Script

- `/.github/scripts/verify-dependency-sources.sh`

This script runs:

- in pre-push hook (`/.githooks/pre-push`)
- in CI (`/.github/workflows/public-ci.yml`)

## Local Development With Remote Manifests (SwiftPM Mirrors)

Requirement:

- Use remote URLs in manifests for CI.
- Work locally on checkouts without committing `.package(path:)`.

Solution:

Use SwiftPM mirrors (per-user, stored under `~/.swiftpm`).

Scripts:

- `/Scripts/spm-mirrors/install.sh`
- `/Scripts/spm-mirrors/status.sh`
- `/Scripts/spm-mirrors/uninstall.sh`

How it works:

- We keep `.package(url: ...)` in git.
- Locally we mirror those URLs to `file:///Volumes/...` folders.
- CI has no mirrors installed, so it resolves from remote.

Common Xcode fix if it “sticks” to an old revision:

- Xcode: `File > Packages > Reset Package Caches`, then `Resolve Package Versions`
- Or delete DerivedData for the app

## What We Still Can’t Prove (Yet)

There are two things we should avoid claiming as fact without stronger evidence:

1. Exact internal implementation of RCP’s USD-to-viewport mapping.
2. Whether RCP uses private APIs or internal metadata channels to retain stable prim identity through RealityKit import.

What we can say defensibly:

- RCP authors transforms into USD as `xformOp` ops (confirmed in the reference project).
- RCP’s viewport feels live and camera-stable during transform edits.
- Public RealityKit APIs do not provide importer provenance metadata (prim path), so we must implement best-effort mapping if we want live updates without a full reload.

## Next Steps (After This Phase)

- Implement stable selection via viewport picking and selection synchronization:
  - Pick `Entity` in the viewport.
  - Resolve to prim path (via tagged component or best-effort inference).
  - Drive scene graph selection + inspector state from that prim path.
- Expand inspector beyond Transform:
  - References, material bindings, primitive parameters.
  - This likely requires adding new typed DTOs to `USDInterfaces` and implementing typed endpoints in `USDInteropAdvanced` (schemas, authored attributes, relationships).

