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

### Phase 0 — Setup ✅
- [x] Confirm SwiftUsdShellOpenUSD API surface covers our needs (read swiftinterface).
- [x] Create dedicated worktree at `.claude/worktrees/usdinterop-sunset` on branch `worktree-usdinterop-sunset` (rebased onto `feature/swift-usd-shell-migration`).
- [x] Save this plan.
- [x] **Atomic manifest swap committed as `e1589f1`.** Root + inner manifests now consume `SwiftUsd-binaries` + `SwiftUsdShell-binaries`; `Reality2713/USDInterop` is dropped. Build is intentionally broken at this commit — subsequent commits port the source.

### API ground truth (from swiftinterface in `/private/tmp/openusdkit-swiftusdshell-binary-slice/0.3.124-macos-arm64.2/xcframeworks/SwiftUsdShell.xcframework`)

```swift
public struct USDStageURL: ... { public init(_ url: Foundation.URL) }
public struct USDPath:     ... { public init(_ rawValue: String) }

// All writes flow through this enum:
public enum USDEditRequest: ... {
    case setDefaultPrim(stageURL:, primPath:)
    case setMetersPerUnit(stageURL:, value:)
    case setUpAxis(stageURL:, axis: USDToken)
    case setPrimTransform(stageURL:, primPath:, transform: USDTransformData, options: USDTransformEditOptions)
    case applySchema(stageURL:, primPath:, schemaName: USDToken)
    case bindMaterial(stageURL:, primPath:, materialPath:, strength: USDMaterialBindingStrength)
    case setMaterialBindingStrength(stageURL:, primPath:, strength:)
    case setVariantSelection(stageURL:, primPath:, setName: USDToken, selectionId: USDToken?)
    case setActive(stageURL:, primPath:, active: Bool)
    case blockAttribute(stageURL:, primPath:, attributeName: USDToken)
    case save(stageURL:)
    // ...
}

final public class OpenUSDStageRuntime: Sendable {
    public init()
    func edit(_: USDEditRequest) async throws -> USDEditResult
    func stageMetadata(stageURL:) throws -> USDStageMetadata
    func primSummary(stage:, primPath:) throws -> USDPrimSummary
    func primTransformData(stage:, primPath:) throws -> USDTransformData?
    func primMaterialBinding(stage:, primPath:) throws -> USDMaterialBindingInfo?
    func materialSummaries(stage:) throws -> [USDMaterialSummary]
    func primReferences(stage:, primPath:) throws -> [USDReference]
    func addReference(stage:, primPath:, reference:) throws
    func removeReference(stage:, primPath:, reference:) throws
    func variantDescriptors(stage:, primPath:) throws -> [USDVariantSetSummary]
    // + materialSurfaceShader / attributeValue (for material property reads)
    // + writeMaterialBindingLayer / writeMaterialUnbindingLayer (session-layer flow)
}
```

### Phase 1 — Port DeconstructedShellRuntime ← in progress (worktree, this branch)

Mechanical rewrite, ~14 call sites. Drop the `bridgeMaterial*` / `bridgeReference` helpers — types are unified across `SwiftUsdShell` now.

- [ ] `USDOperationsClient().X(url:, ...)` → `OpenUSDStageRuntime().X(stage: USDStageURL(url), ...)` (most are now `throws`)
- [ ] Drop `import USDInterfaces` / `import USDOperations`
- [ ] Replace `USDInterfaces.USDTransformData` / `USDMaterialBindingStrength` / `USDReference` with `SwiftUsdShell.*`
- [ ] `setMaterialBinding` semantically differs (session-layer vs. in-place) — prefer `runtime.edit(.bindMaterial(...))` to preserve current in-place behavior
- [ ] `materialProperties(url:, materialPath:)` reshapes — combine `materialSurfaceShader(_:)` + `attributeValue(_:)`

### Phase 2 — Port DeconstructedUSDInterop

~2400 lines of mostly direct Cxx OpenUSD (`UsdStage`, `SdfPath`, `VtValue`, `TfToken`). Those imports come from `SwiftUsd-binaries`' `OpenUSD` target now and should compile unchanged.

- [ ] Drop `import USDInterop` / `import USDOperations` / `import USDInterfaces`
- [ ] Keep `@_implementationOnly import OpenUSD` (resolves through SwiftUsd-binaries)
- [ ] Replace `operationsClient` singleton with `OpenUSDStageRuntime` adapter
- [ ] Audit each Cxx interop call for SDK-version drift

### Phase 3 — Land

When Phase 1 + 2 done: `swift build --target InspectorUI` must complete with no OpenUSD source compile. Expected ~6–10s (matches prior binary-slice timing in `Docs/Inspector-Parity-Progress.md`-era tests). Then merge `worktree-usdinterop-sunset` back into `feature/swift-usd-shell-migration`.

### Phase 4 — Cleanup
- [ ] Delete `Packages/DeconstructedLibrary/Sources/InspectorUI/`, `.../InspectorFeature/` (orphan; user confirmed deletion in Phase 4).
- [ ] Refresh `AGENTS.md`, `CLAUDE.md`, `Docs/SwiftUsdShell-Boundary-Manifesto.md` to drop `USDInterop` references.

## Why a worktree

The migration code in Phase 1–2 will be partially broken at intermediate commits (different APIs). Keeping it off `feature/swift-usd-shell-migration` until it builds means:
- `feature/swift-usd-shell-migration` stays buildable for ongoing inspector/parity work.
- The manifest swap lands as a single reviewable commit, not a series of broken intermediate states.
- If the port stalls, we can park the worktree and continue with main work.

## Resume-from-interruption

Worktree lives at `.claude/worktrees/usdinterop-sunset` on branch `worktree-usdinterop-sunset`. `feature/swift-usd-shell-migration` is unaffected — keep using it for parity work.

Pick-up steps:
1. `cd .claude/worktrees/usdinterop-sunset && git log --oneline -5` to see current state.
2. Latest landed commit: `e1589f1 [WIP] Swap manifests to SwiftUsd-binaries + SwiftUsdShell-binaries`. Graph resolves; source files still import old modules → build is intentionally broken.
3. Next file to port: `Packages/DeconstructedLibrary/Sources/DeconstructedShellRuntime/DeconstructedShellRuntime.swift` (14 call sites — see API mapping table above).
4. Then `Packages/DeconstructedLibrary/Sources/DeconstructedUSDInterop/DeconstructedUSDInterop.swift` (~2400 lines, mostly direct Cxx OpenUSD that should compile unchanged).
5. Done when `swift build --target InspectorUI` succeeds AND `find .build/arm64-apple-macosx/debug -name "OpenUSD.build" -newer Package.resolved` is empty.

## Estimate

Multi-day. Each call site in DeconstructedShellRuntime is mechanical (~10 min for the 14 reads/writes); DeconstructedUSDInterop is closer to ~2 days because each Cxx routine needs validation against the binary OpenUSD headers.

---

## STATUS: Phases 1–3 COMPLETE (binary build green)

The full app library (`DeconstructedUI`) and entire package build against the
binary slice with **zero OpenUSD source compilation**.

Commits on `worktree-usdinterop-sunset`:
- `e1589f1` manifest swap to SwiftUsd-binaries + SwiftUsdShell-binaries
- `c3c4963` port DeconstructedShellRuntime to OpenUSDStageRuntime
- (port) DeconstructedUSDInterop to binary OpenUSD (pxr **v0_26_5**, via the
  re-exported namespace — the version is stamped in the binary, see header note)
- (fix) raw-string `getPrimAttributes` via new `parseAuthoredAttributesFromUSDA`
  USDA text walker; dropped dead `executeMaterialEdit` stub

Verified:
- `swift build` (whole package) → Build complete
- `swift build --target DeconstructedUI` → 21.7s cold
- `swift build --target InspectorUI` → 7.4s
- no `OpenUSD.build` / `SwiftUsd*.build` dirs in `.build/arm64-apple-macosx/debug`
- no `import USDInterop/USDOperations/USDInterfaces` in active shell sources

### Gotchas found vs. the plan
1. **pxr namespace version**: binary OpenUSD ships `pxrInternal_v0_26_5__pxrReserved__`,
   not `v0_26_3`. The re-exported `pxr` alias can't be used for member-type
   lookups, so the file aliases the versioned namespace directly. If the binary
   bumps OpenUSD again, update the one `fileprivate typealias pxr = ...` line.
2. **getPrimAttributes shape**: must return raw USDA-literal strings (inspector
   parses them), NOT `primSummary`'s structured `USDValue`. Reimplemented with a
   text walker.
3. **executeMaterialEdit**: referenced `USDMaterialEditRequest/Result` that don't
   exist in the binary SwiftUsdShell. It was an unused all-`notImplemented` stub —
   deleted.

### Remaining (Phase 4 — cleanup, optional)
- Delete orphan `Sources/InspectorUI/` + `Sources/InspectorFeature/` (still import
  USDInterfaces but are NOT in the active build graph — they're dead dirs).
- Refresh AGENTS.md / CLAUDE.md / boundary manifesto.
- Merge `worktree-usdinterop-sunset` → `feature/swift-usd-shell-migration`.
