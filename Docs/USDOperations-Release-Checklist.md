# USDOperations Split Release Checklist

## Purpose

This checklist defines the minimum release-hardening work required before treating the `USDOperations` split as complete and broadly releasable.

It is intentionally narrower than a full product release checklist. It exists to answer one question:

> Is the public/private USD boundary now stable, honest, and maintainable?

## Release Decision

The split should be considered ready only if every **Required** item passes.

Optional items are quality improvements, not blockers.

## Current Snapshot

As of 2026-03-21:

- already done:
  - `Deconstructed` public build path no longer depends on `USDTools` or legacy advanced products
  - stale `DeconstructedUSDPipeline.swift` was removed
  - public-boundary CI guardrails exist in `Deconstructed`
  - active docs describe the `USDOperations` split
  - RealityKit/component authoring in `DeconstructedUSDInterop` is explicitly treated as app-local open logic
- still blocking a clean release:
  - no known blocker remains in the published `USDInterop` release for this split
- not a blocker, but still cleanup debt:
  - older historical documents still mention `USDInteropAdvanced`, but they are now marked as historical rather than current architecture

## 1. Package and Version Integrity

### Required

- [ ] `USDInterop` published version used by consumers exports `USDOperations`
Pass:
  - `git show <released-tag>:Package.swift` includes `.library(name: "USDOperations", ...)`
  - `Package.resolved` in `Deconstructed` and `Preflight` resolves to that version
Fail:
  - consumers declare `USDOperations` but the resolved tag does not export it

Current status:
  - passes for `v0.1.13`

- [ ] `USDTools` published version matches the shared `USDInterfaces` DTO boundary
Pass:
  - consumer builds do not require local unpublished fixes for shared DTO changes such as `USDReference`
Fail:
  - local checkout works, clean clone fails due to mismatched package releases

Current status:
  - appears to pass for the currently tested graph

- [ ] Clean dependency resolution works from a fresh clone
Pass:
  - `swift package resolve` or `xcodebuild -resolvePackageDependencies` succeeds without local path edits
Fail:
  - build only works because of local package overrides, untagged changes, or unpublished manifests

Current status:
  - resolution passes
  - the published `USDInterop v0.1.13` release includes the `RotationOrder` fix

## 2. Public Boundary Correctness

### Required

- [ ] `Deconstructed` public build path does not require `USDTools`
Pass:
  - main package graph for `Deconstructed` resolves using only `USDInterop` family public products
Fail:
  - any open target directly imports or depends on `USDTools`, `USDTools*`, `USDInteropAdvanced*`, or equivalent private products

Current status:
  - passes

- [ ] `USDOperations` surface remains generic
Pass:
  - exported APIs are limited to generic scene operations such as metadata, transforms, refs, variants, materials, prim create/delete
Fail:
  - workflow logic, heuristics, validation execution, packaging, texture conversion, or product-specific authoring enters `USDOperations`

Current status:
  - passes, with ongoing review discipline still required

- [ ] `USDTools` still owns the private value layer
Pass:
  - surgery, workflows, diagnostics, packaging, texture conversion, plugin orchestration, caching, and session-specific tooling remain private
Fail:
  - those capabilities migrate into the public package family without an intentional business decision

Current status:
  - passes

## 3. Deconstructed Cleanup

### Required

- [ ] Stale advanced-only source is either removed, quarantined, or clearly marked non-participating
Pass:
  - files such as `DeconstructedUSDPipeline.swift` are either deleted, excluded from active build paths, or documented as intentionally dormant
Fail:
  - old advanced-path source remains in-tree in a way that confuses contributors about the supported architecture

Current status:
  - passes

- [ ] Deferred/legacy references to old advanced tooling are removed from user-facing or developer-facing surfaces
Pass:
  - no misleading comments/help text implying the main open path still depends on old advanced modules
Fail:
  - docs, inline help, or code comments still point contributors toward the retired private path

Current status:
  - passes for active surfaces
  - historical notes remain, but are explicitly labeled as historical

- [ ] RealityKit authoring intent is explicitly decided
Pass:
  - team records whether the remaining app-local RealityKit/component authoring in `DeconstructedUSDInterop` is intentionally open or scheduled for later trimming
Fail:
  - scope remains ambiguous and future contributors cannot tell whether that surface is part of the intended public editor

Current status:
  - passes

### Optional

- [ ] Split app-local RealityKit authoring into a separate clearly named file/module
Pass:
  - generic operations bridge and app-local authoring logic are no longer mixed in one large file

## 4. Guardrails Against Drift

### Required

- [ ] Boundary guard exists for open `Deconstructed` targets
Pass:
  - CI or pre-push fails on imports/dependencies of `USDTools`, `USDTools*`, `USDInteropAdvanced*`, or other private modules from open targets
Fail:
  - boundary relies on memory and code review only

Current status:
  - passes

- [ ] Boundary guard exists for `USDOperations` scope
Pass:
  - code review rule, CI script, or documented contract states that `USDOperations` is generic scene ops only
Fail:
  - no mechanism exists to prevent workflow/value logic from drifting into the public layer

Current status:
  - partially passes through docs and boundary guidance
  - could still be strengthened later with repo-local automation in `USDInterop`

- [ ] `USDInterfaces` contract growth is monitored
Pass:
  - additions to `USDInterfaces` are reviewed as public API vocabulary, not just convenient shared types
Fail:
  - `USDInterfaces` slowly becomes a public dump of all `Preflight` concepts without deliberate review

Current status:
  - documented, but still a review-discipline item rather than an automated check

## 5. Behavioral Validation

### Required

- [ ] Public editor path is functionally credible
Pass:
  - open, inspect, navigate, transform, edit refs/variants/materials, create/delete prims, save
Fail:
  - public path compiles but is too crippled for normal editor use

Current status:
  - passes from current manual validation

- [ ] No obvious visual or interaction regressions in the post-split build
Pass:
  - manual smoke test shows no significant UI regression in the supported open path
Fail:
  - boundary cleanup introduced visible breakage or missing core interactions

Current status:
  - passes from current manual validation

- [ ] Build verification covers both package resolution and compile
Pass:
  - at least one successful build path exists for `Deconstructed`, and one for `PreflightUSDInterop` or equivalent integration target
Fail:
  - evaluation is based on resolution only, without a compile confirmation

Current status:
  - passes locally
  - published package versions now match the validated split

## 6. Documentation Integrity

### Required

- [ ] Architecture docs match reality
Pass:
  - docs describe `USDOperations` as a target inside the `USDInterop` package family
  - docs do not claim an unpublished or superseded dependency shape
Fail:
  - docs still describe `USDToolsLite`, old advanced package names, or outdated release concerns as current truth

Current status:
  - passes for active docs

- [ ] Evaluation doc reflects the implemented state
Pass:
  - completed items are marked complete
  - remaining risks are current and specific
Fail:
  - doc mixes historical concerns with current blockers without distinguishing them

Current status:
  - passes

## Final Gate

The split is ready to treat as complete only when all of these are true:

- package versions and clean-clone resolution are correct
- `Deconstructed` no longer depends on private tooling for its public build path
- stale advanced-path confusion is cleaned up
- the remaining open RealityKit authoring scope is explicitly intentional
- boundary guardrails exist
- behavioral smoke testing passes
- docs describe the current system, not an earlier draft of it

If any required item fails, the correct conclusion is:

> The architecture is validated, but the release hardening is incomplete.
