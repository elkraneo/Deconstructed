# SwiftUsdShell Migration — Regression Ledger

Tracks functionality differences between the pre-refactor USD stack
(`USDInterop` / `USDOperations`, source, OpenUSD-Cxx) and the current
SwiftUsdShell stack (`SwiftUsdShellOpenUSD` / `OpenUSDStageRuntime` binary +
`DeconstructedUSDInterop` text-authoring layer).

Status date: 2026-05-29. Derived from a four-angle audit (capability diff via
git history, stub scan, read-path parity, UI feature surface). Confidence is
**high** for code-structural findings (stubs, dropped params, `.usda`-only
guards) and **medium** where a pre/post attribution rests on reading the
pre-migration commit.

Legend — Status: ✅ fixed · 🔴 confirmed regression (open) · 🟡 degraded/fragile ·
⚪️ pre-existing gap (NOT a migration regression) · 🟢 improvement.

---

## Fixed in this pass

| Item | Was | Now | Ref |
|---|---|---|---|
| ✅ USDA prim-scope walker desync | ~10 inline naive `{`/`}` walkers in `DeconstructedUSDInterop`; "Target prim not found: /Root/Cone" when authoring components | Shared `DeconstructedModels.USDAPrimScopeTracker` (string/paren/dict-aware); all sites converted | `DeconstructedUSDInterop.swift`, `USDAPrimScopeTracker.swift` |
| ✅ Scene navigator mis-nesting | `SceneGraphClient.parseSceneNodes` naive walker | Uses shared tracker, path-indexed tree | `SceneGraphClient.swift` |
| ✅ Composition arcs | `primCompositionArcs` hard `[]` stub | Reads reference + payload arcs via `OpenUSDStageRuntime.inspectPrim(includeCompositionArcs:)`; adapter now `async` | `DeconstructedShellRuntime.swift`, `SceneInspectorClient+Live.swift` |

---

## Confirmed regressions — open (🔴 / 🟡)

### High
| Item | Pre (USDInterop) | Now | Impact |
|---|---|---|---|
| 🟡 Scene bounds | real geometry traversal | `DeconstructedUSDInterop.getSceneBounds` returns zero **but has no callers** — fully dead. Viewport framing is owned by the external `RealityKitStageView` package (its own bounds fallback). The runtime *does* expose `sceneBounds` via `inspectStage`/`inspectPrim(includeBounds:)` if a caller is ever added. | No live user-facing effect today; downgraded from 🔴. |
| 🟡 Prim/component attribute reads | `UsdPrim.GetAuthoredAttributes()` (typed, composition-aware) | `parseAuthoredAttributesFromUSDA` text regex (root layer only, truncates multi-line arrays) | Inspector attribute + component-param panels; misses inherited/referenced opinions. (Severity depends on whether pre-migration was truly Cxx here — medium confidence.) |
| 🟡 Material properties | per-prim Cxx attributes | text walk; all `propertyType = .unsupported` | No typed material editors (color swatch/sliders). |
| 🟡 Raw component-attribute editing | real path in legacy InspectorFeature | `setRawComponentAttributeRequested` hard-stub ("requires the SwiftUsdShell runtime adapter") | Generic (non-catalog) component attribute edits dead. |

### Medium
| Item | Pre | Now | Impact |
|---|---|---|---|
| 🟡 `exportUSDA` | flattened composed-stage export | raw `String(contentsOf:)` | No flattening; `.usdc`/`.usdz` unsupported. |
| 🟡 Unique-name generation | `UsdPrim.GetChildren()` | `listChildPrims` text walk | Misses children in referenced/variant layers → name collisions in composed stages. |
| 🟡 `clearMaterialBinding` | `UnbindDirectBinding()` | `blockAttribute("material:binding")` | Block overrides inherited bindings; unbind does not — different semantics. |
| 🟡 `editTarget` / `persist` dropped | forwarded on bind / variant / reference / strength edits | always root layer | Session-layer (preview/undo) overrides unreachable. |
| 🟡 `prim.kind` / animation tracks | kind on prim tree; full track list | kind dropped from `USDPrimTree`; tracks collapsed to a count | Lost model-kind cues / per-track metadata. |

---

## Cross-cutting

| Item | Detail |
|---|---|
| 🟡 Binary stages (`.usdc`/`.usdz`) | The text-fallback layer is `.usda`-only (guards in `getPrimAttributes`, `listRealityKitComponentPrims`, `listChildPrims`, `addRealityKitComponent`, `ensureTypedPrim`, `setRealityKitComponentParameter` fallback, `exportUSDA`, `SceneGraphClient`). `USDOperations` was Cxx and could read binary. So opening a non-`.usda` project: empty component list/attrs/materials, add-component throws, scene navigator empty. ~9 ops degraded. **Decision needed:** route more reads through `OpenUSDStageRuntime` vs. document `.usda`-only. |
| ⚪️ Dead secondary parser | `DeconstructedShellRuntime.parseStage`/`primTree` still uses naive brace handling and is `def Type "Name"`-only, but has **no callers**. Flagged in-code to adopt `USDAPrimScopeTracker` if revived. |
| 🟡 Silent stubs mask missed installs | `SceneInspectorClient` default `liveValue` returns `""`/`[]`/no-op instead of throwing. If `AppFeature.liveDependenciesInstalled` ever fails to run, writes silently no-op. Prefer throwing stubs (as `SceneEditClient` does). |

---

## Pre-existing gaps — NOT migration regressions (⚪️)

These were already broken/unimplemented before the migration; listed so they
aren't mis-attributed.

- `executeMaterialEdit` — was all-`notImplemented`; removed. ✅ The obsolete
  `materialEditRuntimeReportsUnsupportedExecution` test that referenced it has
  been removed, so `DeconstructedShellRuntimeTests` compiles again. The
  material-edit DTO contracts remain covered by the Codable round-trip tests.
- `editHierarchy` — always `notImplemented` (reparent/reorder).
- Prim delete / rename / reparent — no UI wiring.
- Visibility write — inspector shows it read-only; no setter.
- Scene statistics panel — `ContentUnavailableView`.
- "Remove Overrides" / "Convert Variants to Configurations" buttons — `.disabled(true)`.

---

## Improvements (🟢)

- `applySchema` — was `notImplemented` pre-migration; now implemented via
  `OpenUSDStageRuntime`.

---

## Suggested priority

1. ✅ Walker fixes (done).
2. Binary-stage policy decision (cross-cutting) — biggest user-facing multiplier.
3. ✅ Composition arcs (wired to `inspectPrim`). Scene bounds: dead code, no
   live effect — deferred, not a real regression.
4. ✅ Fix `DeconstructedShellRuntimeTests` `executeMaterialEdit` reference so the
   test target compiles (obsolete test removed).

---

## USDInterop sunset readiness

**Verdict: the build-graph sunset is already done; what remains is dead-code
cleanup and a short list of *non-blocking* degraded items.**

Build-graph state (confirmed on `feature/swift-usd-shell-migration`):

- The manifest no longer depends on `Reality2713/USDInterop` (only
  `SwiftUsd-binaries` + `SwiftUsdShell-binaries`). The app builds and runs on
  the binary slice with zero OpenUSD source compilation.
- The live inspector is `Sources/InspectorShellFeature` + `Sources/InspectorShellUI`,
  compiled under the module names `InspectorFeature` / `InspectorUI` via a
  `path:` remap. The old `Sources/InspectorFeature/` + `Sources/InspectorUI/`
  dirs are **orphans** (no target's `path:` points at them).
- The **only** remaining `import USDInterfaces` / `USDOperations` / `USDInterop`
  statements live in those 3 orphan files
  (`InspectorFeature/InspectorFeature.swift`, `InspectorUI/InspectorView.swift`,
  `InspectorUI/AudioMixGroupsEditor.swift`). Every *compiled* source is clean.

So nothing in the active build path needs USDInterop. Sunsetting it means:

1. Delete the orphan dirs `Sources/InspectorFeature/` + `Sources/InspectorUI/`
   (Phase 4 of `USDInterop-Sunset-Migration.md`).
2. Refresh `CLAUDE.md` / `AGENTS.md` / boundary manifesto to drop USDInterop
   references.

### Feature parity vs. the USDInterop stack

Backed by the **real binary runtime** (`OpenUSDStageRuntime`): stage metadata,
prim summary/tree, prim transform read+write, material bindings (bind/unbind/
strength), references add/remove, variant sets + selection, default prim,
metersPerUnit, up-axis, applySchema, **composition arcs (new)**.

Backed by the **open text layer** (`DeconstructedUSDInterop`, `.usda` only):
component add/remove + parameter edits, child-prim listing, authored-attribute
reads, behaviors, audio mix groups, animation-library resources, scene
navigator.

**Non-blocking gaps that remain** (none require USDInterop — they are either
SwiftUsdShell runtime feature requests or accepted text-layer approximations):

- Typed material property editors → currently `.unsupported` (raw literal text).
- Raw (non-catalog) component-attribute editing → hard-stub.
- `exportUSDA` flattening + `.usdc`/`.usdz` → raw root-layer read only.
- Binary-stage (`.usdc`/`.usdz`) reads → text fallback is `.usda`-only. **Policy
  decision still open** (route through runtime vs. scope to `.usda`).
- `prim.kind` cue + per-animation-track metadata → collapsed.

**Conclusion:** USDInterop can be sunset now. The remaining gaps are tracked
above and are independent of whether USDInterop stays in the tree.
