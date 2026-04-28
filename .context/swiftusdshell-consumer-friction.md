# SwiftUsdShell consumer report from Deconstructed

Date: 2026-04-28

## Context

Deconstructed is using `SwiftUsdShell` to validate whether an OpenUSD-heavy macOS app can keep feature and UI targets free of direct `SwiftUsd`/`OpenUSD` dependencies. The target consumer shape is:

```text
Feature/UI code -> Shell DTOs + runtime client protocols -> SwiftUsdShell runtime adapter -> OpenUSD
```

The important requirement is that app feature targets must not import or build `OpenUSD`, `USDInterop`, `USDInterfaces`, `USDOperations`, or Cxx interop just to inspect or edit a stage. Those dependencies should be isolated behind a runtime implementation target.

## Compile friction

- The failing Xcode build was not caused by `SwiftUsdShell` itself. `SwiftUsdShell` 0.3.2 builds as a pure Swift target in about five seconds.
- The OpenUSD compile errors came from Xcode resolving `USDInterop` 0.1.13, which pinned `SwiftUsd` to `6.1.0-preflight.1`.
- Root SwiftPM resolution moved `USDInterop` to 0.1.17 and `SwiftUsd` to `6.1.0-preflight.3`, which is the version that should avoid the reported `OpenUSD` module errors.
- Xcode kept the older workspace `Package.resolved` pins until updated explicitly. This is a practical consumer hazard because the manifest range allows a working version while Xcode can silently keep a broken transitive pin.
- Even after updating pins, the full app still failed if any active app target depended on `DeconstructedUSDInterop`, `USDInterfaces`, or old inspector sources. Xcode eagerly built the `OpenUSD` package product through those target graph edges.
- Deconstructed now compiles by replacing the OpenUSD-backed inspector target path with shell-safe placeholder targets and by removing accidental bridge dependencies from project browser, scene graph, viewport, and document feature targets.

## Current Deconstructed workaround

Deconstructed currently has:

- `DeconstructedShellRuntime`: a pure Swift target that imports `SwiftUsdShell` only.
- Shell-safe `InspectorFeature` and `InspectorUI` placeholder targets under `Sources/InspectorShellFeature` and `Sources/InspectorShellUI`.
- Legacy `DeconstructedUSDInterop` still in the repo as reference/bridge code, but no longer in the active app target graph.
- Scene graph and project browser clients no longer import the OpenUSD bridge.

This lets:

```bash
xcodebuild -workspace Deconstructed.xcworkspace -scheme Deconstructed -destination 'platform=macOS' build
```

complete without compiling `OpenUSD/SwiftOverlay/Sequence.swift`.

## Shell API friction

- `SwiftUsdShell` 0.3.2 is a DTO/contract package, not a runtime. Consumers still need a runtime bridge to open files, query USD, and execute edits.
- Material edit planning types from the previous local integration (`USDPreparedMaterialEdit`, branch plans, readiness, edit policies) are no longer in the shell. That separation is cleaner, but consumers need to know where planning policy should live.
- Current Deconstructed runtime still depends on `USDOperations`/`USDInterop`, so any target that builds the runtime still pays the full OpenUSD compile cost. The shell boundary helps downstream modules only if they depend on shell DTOs instead of runtime implementation targets.
- Error reporting from the runtime boundary is still local. The shell gives stable request/result types, but not a standard runtime capability/error model beyond broad `SwiftUsdShellError` cases.

## Required runtime capabilities

To reconnect Deconstructed's inspector without reintroducing direct OpenUSD dependencies, Shell needs a runtime surface that can perform these operations using pure Swift public DTOs.

### Stage inspection

- Open/read a USD stage from `URL`.
- Return stage metadata:
  - default prim
  - available prim paths
  - meters per unit
  - up axis
  - time codes per second / start / end if available
- Return a prim tree with stable IDs, display names, paths, type names, active/defined/abstract metadata if available.
- Return a lightweight prim summary suitable for inspector selection.

### Prim inspection

- Read authored attributes for a prim as shell DTOs:
  - attribute name
  - declared value type
  - raw USDA-ish display value
  - authored/default/time-sampled status if available
- Read relationships and targets.
- Read transform data:
  - position
  - rotation degrees or quaternion, with documented convention
  - scale
  - xform op order if exposed
- Read references:
  - asset path
  - prim path
  - layer offset/scale if available
- Read variant sets:
  - set name
  - choices
  - current selection
  - authored site if available

### Editing

- Set stage metadata:
  - default prim
  - meters per unit
  - up axis
- Set prim transform.
- Add/remove/replace references.
- Set variant selection.
- Create primitive and structural prims.
- Delete prims.
- Save changes.
- Return an edit result that tells the caller what to refresh:
  - viewport reload needed
  - scene graph refresh needed
  - inspector refresh needed
  - thumbnail invalidation needed
  - selection path changed

### Materials

- List materials in the stage.
- Read material info and authored material properties.
- Read material binding and binding strength for a prim.
- Set/clear material binding.
- Set binding strength.
- Provide stable DTOs for material property display without leaking OpenUSD value types.

### RealityKit component workflows

Deconstructed's current inspector needs Reality Composer Pro / RealityKit component support. Shell should expose generic enough DTOs to avoid baking Deconstructed-specific UI policy into the shell.

- List RealityKit component prims for a selected prim.
- Read component authored attributes.
- Read component descendant attributes for nested authored data like audio mix groups.
- Add a component by identifier.
- Delete a component.
- Set component active/inactive.
- Set/delete component parameter values.
- Upsert audio file resources used by RealityKit audio components.
- Set audio library resources / mix group resource links.
- Ensure typed helper prims where the component model requires them.

### Bounds and thumbnails

- Read stage/prim bounds as a pure Swift DTO.
- Provide enough information for thumbnail camera placement:
  - min
  - max
  - center
  - max extent
- This replaces Deconstructed's temporary text `extent = [...]` heuristic.

## DTO requirements

- Public Shell DTOs should be pure Swift.
- No public `OpenUSD`, `USDInterop`, `USDInterfaces`, or C++ types.
- Prefer `Sendable` on all public data used by app features.
- Prefer `Codable` for requests/results that may be logged, tested, or routed through a process boundary.
- Prefer stable string/raw-value enums for USD concepts that may grow over time, with an unknown/custom case where appropriate.
- Use `Double` for transform DTOs if the consumer is expected to interoperate with StageView live transforms; Deconstructed's viewport path expects `SIMD3<Double>`.
- Errors should be typed and inspectable:
  - file not found
  - stage open failed
  - prim not found
  - unsupported schema
  - invalid value
  - save failed
  - runtime unavailable
  - underlying diagnostic text

## Adapter shape requested

The ideal public API shape is a client/protocol that Deconstructed can wrap in TCA dependencies:

```swift
public protocol USDStageRuntime: Sendable {
  func inspectStage(_ request: USDStageInspectRequest) async throws -> USDStageInspection
  func inspectPrim(_ request: USDPrimInspectRequest) async throws -> USDPrimInspection
  func edit(_ request: USDEditRequest) async throws -> USDEditResult
}
```

The concrete OpenUSD-backed implementation can live in a separate product. The key is that the protocol and DTO product must not build OpenUSD when imported.

Recommended product split:

```text
SwiftUsdShell          # DTOs, protocols, request/result types, no OpenUSD
SwiftUsdShellOpenUSD   # concrete OpenUSD adapter, allowed to import SwiftUsd/OpenUSD
```

Deconstructed should depend on `SwiftUsdShell` in feature/UI targets and only wire `SwiftUsdShellOpenUSD` at the composition/runtime boundary if needed.

## Reconnection criteria for Deconstructed

The placeholder inspector can be replaced when Shell can provide:

1. Stage metadata and prim tree loading for the currently open scene.
2. Prim authored attributes and transform inspection for the selected prim.
3. Transform editing and save.
4. Reference and variant editing.
5. Material binding read/write.
6. RealityKit component read/write for the component workflows currently in Deconstructed's inspector.
7. Edit result refresh hints so Deconstructed can update viewport, scene graph, thumbnails, and inspector without guessing.

Until then, reconnecting inspector directly to `DeconstructedUSDInterop` will make the app compile path fragile again because feature/UI targets will trigger OpenUSD compilation.

## Recommended product improvements

- Keep package release notes explicit about compatible `USDInterop` and `SwiftUsd` versions.
- Add a tiny runtime protocol package or sample adapter showing how an app should map shell DTOs to an OpenUSD backend.
- Document that planning/conversion policy is intentionally above the shell, with an example for material edits.
- Provide a consumer smoke-test target that imports only `SwiftUsdShell`, and another that exercises the canonical runtime bridge, so version failures are easy to isolate.
- Add an Xcode workspace smoke test in CI, not only `swift build`, because the original failure reproduced through Xcode package resolution and DerivedData package pins.
