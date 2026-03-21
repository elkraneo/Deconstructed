# Material Bindings Phase Notes (RCP Parity)

This document captures what we learned about Reality Composer Pro (RCP) material bindings and what we implemented in this phase across the USD interop stack.

> Historical note:
> This document predates the `USDOperations` split. References to `USDInteropAdvanced`
> describe the earlier private advanced layer, not the current public boundary.

## Observations

- RCP's viewport behavior suggests it is backed by RealityKit rendering (not Hydra):
  - Some USD features (notably instancing in some assets) appear correct in Hydra but are broken/magenta in RealityKit.
  - Finder's USD preview seems to be Hydra-backed (renders some instanced content more correctly than RealityKit).
- For Deconstructed, we treat USD as the source of truth and avoid "decorative" state: inspector UI reads authored USD, and editing operations author USD.

## How USD Represents Material Bindings

Material bindings are authored via `UsdShadeMaterialBindingAPI` on a prim.

Two distinct pieces matter:

- **Bound material path**: the relationship target (which material is bound).
- **Binding strength**: relationship metadata `bindMaterialAs` (token), which controls how the binding composes relative to descendants.

Strength token values in OpenUSD:

- `fallbackStrength` (default)
- `weakerThanDescendants`
- `strongerThanDescendants`

In RCP UI this shows up as the "Strength" picker under *Material Bindings* for some models.

## Implementation (Local-Dev First)

Deconstructed is not allowed to do low-level OpenUSD plumbing for this kind of feature. At the time, the integration boundary was:

`Deconstructed -> USDInteropAdvanced -> USDInterop/SwiftUsd`

Current framing:

`Deconstructed -> USDOperations (generic scene ops) / app-local DeconstructedUSDInterop -> USDInterop/SwiftUsd`

So we implemented:

1. A typed DTO in `USDInterfaces`:
   - `USDMaterialBindingStrength`
2. Typed endpoints in the advanced USD layer:
   - inspection: read binding strength from the direct binding relationship
   - editing: author binding strength on the direct binding relationship

This allows Deconstructed (and other apps, e.g. Preflight) to consume a stable API without re-implementing OpenUSD interop. In the current split, generic binding operations belong in `USDOperations`; higher-level workflows remain private in `USDTools`.

## Local Development Without Breaking CI

CI must remain on remote URLs (`.package(url: ...)`). Local development can route those URLs to local checkouts via SwiftPM mirrors.

Use:

- `Scripts/spm-mirrors/install.sh`
- `Scripts/spm-mirrors/status.sh`
- `Scripts/spm-mirrors/uninstall.sh`

These configure per-user mirrors (stored under `~/.swiftpm`) so local builds use:

- `/Volumes/Plutonian/_Developer/USDInterop`
- `/Volumes/Plutonian/_Developer/AppleUSDSchemas`

without committing any `.package(path: ...)` or `XCLocalSwiftPackageReference` artifacts.

Historical note:

- Mirrors are appropriate for `USDInterop` and `AppleUSDSchemas` (same repo content, different location).
- Older local-development flows also referenced `USDInteropAdvanced`. That is no longer the current public build path for Deconstructed.

## Known Limitations / Next Steps At The Time

- **Deconstructed UI wiring for Strength** depended on an updated advanced-layer release.
- **Viewport updates**:
  - Current approach uses "reload the scene asset" semantics to pick up USD edits.
  - To match RCP's smooth experience, we likely need a prim-path-to-entity mapping and apply changes directly to RealityKit entities (best-effort), while authoring USD on commit.
