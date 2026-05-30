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

---

## Confirmed regressions — open (🔴 / 🟡)

### High
| Item | Pre (USDInterop) | Now | Impact |
|---|---|---|---|
| 🔴 Composition arcs | `primProvenance` → `UsdPrimCompositionQuery` | `primCompositionArcs` returns `[]` | Inspector Composition panel always empty. Needs an `OpenUSDStageRuntime` provenance read (SwiftUsdShell-side). |
| 🔴 Scene bounds | real geometry traversal | `getSceneBounds` returns zero | Camera auto-framing broken. Needs runtime `sceneBounds`. |
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
3. High regressions (composition arcs, scene bounds) — require new
   `OpenUSDStageRuntime` read methods; track as SwiftUsdShell feature requests,
   not Deconstructed bugs.
4. ✅ Fix `DeconstructedShellRuntimeTests` `executeMaterialEdit` reference so the
   test target compiles (obsolete test removed).
