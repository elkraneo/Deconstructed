# USDInterop Sunset — Migration to SwiftUsdShell + SwiftUsdShellOpenUSD

## Goal

Replace Deconstructed's source dep on `Reality2713/USDInterop` (which transitively pulls source `Reality2713/SwiftUsd` and compiles OpenUSD from scratch — ~1.2 GB / many minutes) with the binary-distributed `Reality2713/SwiftUsdShell-binaries` + `Reality2713/SwiftUsd-binaries`. USDInterop will be archived; SwiftUsdShellOpenUSD becomes the canonical runtime.

Tracking issue: <https://github.com/Reality2713/OpenUSDKit/issues/13>.

## Why this has to be atomic

Both `USDInterop → SwiftUsd.git` (source) and `SwiftUsdShell-binaries → SwiftUsd-binaries.git` (binary) declare `OpenUSD` and `_OpenUSD_SwiftBindingHelpers` targets. SPM rejects the graph with:

```
multiple packages declare targets with a conflicting name: 'OpenUSD'
```

So there is no incremental "both in the graph at once" state. The port must complete on a side branch / worktree, then the manifest swap lands as one commit.

## Files that consume USDInterop today

| File | Imports | Notes |
|---|---|---|
| `Packages/DeconstructedLibrary/Sources/DeconstructedShellRuntime/DeconstructedShellRuntime.swift` | `USDInterfaces`, `USDOperations` | 14 `USDOperationsClient()` call sites; bridges between `SwiftUsdShell` DTOs and `USDInterfaces` types |
| `Packages/DeconstructedLibrary/Sources/DeconstructedUSDInterop/DeconstructedUSDInterop.swift` | `USDInterop`, `USDInterfaces`, `USDOperations`, `@_implementationOnly import OpenUSD` | ~2400 lines; the bulk of the work |
| `Packages/DeconstructedLibrary/Sources/InspectorFeature/InspectorFeature.swift` | `USDInterfaces` | Likely an orphan import we can drop; the shell target uses `SwiftUsdShell` DTOs |
| Inner package `Package.swift` (`DeconstructedShellRuntime` target) | `USDOperations`, `USDInterfaces` (linked) | Drop from `dependencies` |
| Root `Package.swift` (`DeconstructedShellRuntime` target + `DeconstructedUSDInterop` target) | Same | Drop |

Orphan files under `Packages/DeconstructedLibrary/Sources/InspectorUI/` also import `USDInterfaces` but are not in the active shell build path; can be removed wholesale at the end if they're truly retired, or left alone if the package still compiles them.

## API mapping (DeconstructedShellRuntime)

`USDOperationsClient()` calls today map to `SwiftUsdShellOpenUSD.OpenUSDStageRuntime` methods (private singleton in the migrated shell runtime). All take `SwiftUsdShell.USDStageURL` / `USDPath` instead of bare `URL` / `String`.

| Old | New |
|---|---|
| `USDOperationsClient().stageMetadata(url:)` | `runtime.stageMetadata(stageURL:)` |
| `USDOperationsClient().primTransform(url:, path:)` | `runtime.primTransformData(stage:, primPath:)` |
| `USDOperationsClient().materialBinding(url:, primPath:)` | `runtime.primMaterialBinding(stage:, primPath:)` |
| `USDOperationsClient().allMaterials(url:)` | `runtime.materialSummaries(stage:)` |
| `USDOperationsClient().materialProperties(url:, materialPath:)` | `runtime.materialSurfaceShader(_:)` / `runtime.attributeValue(_:)` (different shape — may need bridging) |
| `USDOperationsClient().setDefaultPrim(url:, primPath:)` | `runtime.edit(_: USDEditRequest)` (build a typed request) |
| `USDOperationsClient().setMetersPerUnit(...)` | Same — via `USDEditRequest` |
| `USDOperationsClient().setUpAxis(...)` | Same |
| `USDOperationsClient().setPrimTransform(...)` | `runtime.edit(_:)` with a `USDTransformEdit` |
| `USDOperationsClient().setMaterialBinding*(...)` | `runtime.writeMaterialBindingLayer(...)` + `writeMaterialUnbindingLayer(...)` |
| `USDOperationsClient().setPrimVariantSelection(...)` | `runtime.edit(_:)` |
| `USDInterfaces.USDTransformData` (DTO) | `SwiftUsdShell.USDTransformData` (already used; drop the bridge) |
| `USDInterfaces.USDMaterialBindingStrength` | `SwiftUsdShell.USDMaterialBindingStrength` |
| `USDInterfaces.USDReference` | `SwiftUsdShell.USDReference` |

Detailed mapping for the remaining 4-5 ops will land as we touch each call site.

## DeconstructedUSDInterop strategy

This file already calls OpenUSD directly via Cxx interop (`UsdStage.Open`, `SdfPath`, `VtValue`, `TfToken`, etc.). The C++ headers are exposed by `SwiftUsdShell-binaries`' `OpenUSD` binary target the same way they are exposed by `USDInterop` / `SwiftUsd`, so most `@_implementationOnly import OpenUSD` call sites should compile against the binary unchanged. Three classes of edits expected:

1. Drop `import USDInterop` / `import USDOperations` / `import USDInterfaces` headers and replace any references to those modules' Swift types (mostly `USDOperationsClient()` mirror calls inside the file).
2. Keep the USDA text mutator paths intact — they're pure Foundation/String.
3. Anything that uses `USDInterop`-specific Swift wrappers (e.g. `applySchema`, `createPrim`, `setDefaultPrim` via `operationsClient`) needs porting to `OpenUSDStageRuntime` calls.

## Phased plan

### Phase 0 — Setup
- [x] Confirm SwiftUsdShellOpenUSD API surface covers our needs (done — see `*.swiftinterface`).
- [ ] Create a dedicated worktree (`feature/usdinterop-sunset`) so the migration progresses without blocking `main`.
- [ ] Save this plan in `Docs/USDInterop-Sunset-Migration.md` (this file).

### Phase 1 — Migration code (no manifest swap yet)
- [ ] In the worktree: stage a parallel adapter file under `DeconstructedShellRuntime/` that implements every public static currently in `DeconstructedShellRuntime.swift` using `OpenUSDStageRuntime`. Don't replace the existing file yet — write side-by-side, gated by a Swift conditional compile flag (`#if USE_BINARY_OPENUSD`).
- [ ] Run unit tests / build with the flag flipped to confirm parity.

### Phase 2 — DeconstructedUSDInterop port
- [ ] Same pattern: parallel `+SwiftUsdShell.swift` slice exporting the same public statics, behind the same flag.
- [ ] Once at 100 % API coverage and tests pass, retire the original.

### Phase 3 — Manifest swap (atomic commit)
- [ ] Replace `.package(url: "Reality2713/USDInterop", from: "0.1.21")` with:
  ```
  .package(url: "https://github.com/Reality2713/SwiftUsd-binaries.git",      exact: "0.3.124-macos-arm64.2"),
  .package(url: "https://github.com/Reality2713/SwiftUsdShell-binaries.git", exact: "0.3.124-macos-arm64.2"),
  ```
- [ ] Update all `.product(name:package:)` references:
  - `package: "SwiftUsdShell"` → `package: "SwiftUsdShell-binaries"`
  - `package: "USDInterop"` lines → drop, use `SwiftUsdShellOpenUSD` (from `SwiftUsdShell-binaries`)
- [ ] Drop the `USDInteropCxx` swiftSettings (binary distribution handles it).
- [ ] Same change in inner `Packages/DeconstructedLibrary/Package.swift`.
- [ ] Bring up `swift package resolve` → expect clean.
- [ ] `swift build` → expect clean.

### Phase 4 — Cleanup
- [ ] Delete orphan `InspectorUI/` directory tree if dead.
- [ ] Update `AGENTS.md` and `CLAUDE.md` to reflect the new dep structure (drop USDInterop references, add SwiftUsdShellOpenUSD).
- [ ] Update `Docs/SwiftUsdShell-Boundary-Manifesto.md` to reflect the new ground truth.

## Why a worktree

The migration code in Phase 1–2 will be partially broken at intermediate commits (different APIs). Keeping it off `feature/swift-usd-shell-migration` until it builds means:
- `feature/swift-usd-shell-migration` stays buildable for ongoing inspector/parity work.
- The manifest swap lands as a single reviewable commit, not a series of broken intermediate states.
- If the port stalls, we can park the worktree and continue with main work.

## Resume-from-interruption

If interrupted: branch = `feature/usdinterop-sunset` (TBD; create when starting). Check `git diff main..feature/usdinterop-sunset --stat` to see progress. The migration is done when:

1. `git grep -l "import USDInterop\|import USDOperations\|import USDInterfaces\|import USDInteropCxx" Packages/` returns nothing under active sources.
2. `swift build --target InspectorUI` completes under ~10s (binary-slice timing).
3. `find .build/arm64-apple-macosx/debug -name "OpenUSD.build" -newer Package.resolved` returns empty after a fresh resolve.

## Estimate

Realistically a multi-day effort. Each call site in DeconstructedShellRuntime is mechanical (~10 min); DeconstructedUSDInterop is closer to ~2 days because each Cxx routine needs validation that the binary OpenUSD headers match the SDK we currently link.
