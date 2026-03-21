# USDOperations Refactor Evaluation

## Status

- Date: 2026-03-21
- Scope: `Deconstructed`, `USDInterop`, `USDTools`, `Preflight`
- State: post-implementation evaluation before broader release

### Current state snapshot

- Implemented:
  - `USDOperations` exists inside the public `USDInterop` package family
  - `Deconstructed` now builds on the public dependency path
  - stale `DeconstructedUSDPipeline` source was removed
  - public-boundary CI guardrails were added
  - active contributor docs were updated to describe the current split
- Still pending for release hygiene:
  - cut a follow-up `USDInterop` release that includes the post-tag `RotationOrder` fix in `USDOperationsClient`
  - optionally split app-local RealityKit authoring out of `DeconstructedUSDInterop.swift` for clarity
  - continue normal repo hygiene on unrelated historical notes and archived utilities as needed

## Executive Summary

The refactor moved the app-facing generic USD scene operations out of the proprietary advanced tooling boundary and into a new public `USDOperations` target inside the existing `USDInterop` package family.

This was the right architectural direction.

It improves the open-source credibility of `Deconstructed`, preserves the likely product moat for `Preflight`, and fits the Swift/C++ packaging constraint better than a separate `USDToolsLite` package would have.

At the same time, the work is only a partial completion of the original conservative split:

- The package boundary is now correct.
- The public/shared API surface is much cleaner.
- `Deconstructed` can build against the public path.
- `USDTools` still retains the high-value workflow layer.
- But `Deconstructed` still contains a large amount of open, app-specific RealityKit authoring logic in `DeconstructedUSDInterop`, and the "drop from phase 1" trimming was not fully carried through.

The result is good enough to justify the direction and continue. The architecture itself is now validated; the remaining gap is release-hardening rather than architectural uncertainty.

## What We Decided

### Core decision

We rejected the idea of a feature-matrix-style `USDToolsLite` package and chose a cleaner split:

- `USDInterop` remains the public package family that exists primarily to solve Swift/C++ interop packaging constraints.
- `USDOperations` becomes the public app-facing generic operations target inside that package family.
- `USDTools` remains the private high-level tooling and workflow layer.

This means the split is:

- Public: interop + generic scene operations
- Private: workflows, diagnostics, surgery, conversion, packaging, heuristics

### Why this was the right call

`USDInterop` already exists because Swift/C++ interop cannot be shared casually across multiple package consumers. Adding an entirely separate public package on top of it would have created an artificial extra wall. Keeping `USDOperations` inside `USDInterop` gives one public package boundary instead of two competing public abstractions.

## What Changed

### `USDInterop`

`USDInterop` now exports:

- `USDInterop`
- `USDInterfaces`
- `USDInteropCxx`
- `USDOperations`

`USDOperations` now owns the generic app-facing scene operations needed by `Deconstructed`, including:

- scene bounds
- scene graph export
- USDA export
- stage metadata
- prim attributes
- prim transforms
- prim references
- variants
- material bindings
- default prim
- up-axis / meters-per-unit
- prim deletion
- generic prim creation

`USDInterfaces` also became the shared source of DTOs such as `USDReference`, which removes duplication between repos.

### `Deconstructed`

`Deconstructed` now depends on `USDInterop 0.1.13` and imports `USDOperations` from that package family.

The key improvement is that `DeconstructedUSDInterop` now delegates the generic scene operations to `USDOperationsClient` instead of private advanced tooling. This makes the package graph materially more honest for open-source consumers.

At the same time:

- `createPrimitive` and `createStructural` remain open and local to `Deconstructed`, which is correct
- `applySchema` and `editHierarchy` are explicitly not implemented
- a large amount of RealityKit-specific authoring logic still lives in `DeconstructedUSDInterop`

### `USDTools`

`USDTools` was updated to consume the shared DTO boundary and remains the owner of the advanced tooling surface.

Nothing in this refactor suggests that `USDTools` lost its main value-bearing responsibilities:

- texture workflows
- USDZ packaging
- plugin conversion
- stage/session workflows
- surgery and repair
- validation and diagnostics
- performance/caching-oriented tooling

### `Preflight`

`Preflight` was updated to the matching package graph:

- `USDInterop 0.1.13`
- `USDTools 0.2.46`

`PreflightUSDInterop` now declares `USDOperations` as a dependency, but it does not yet materially migrate generic operations to it. In practice, `Preflight` still behaves as a `USDTools` consumer first, which is acceptable for this phase.

## Evaluation

### 1. Business Evaluation

This refactor does not appear to cannibalize `Preflight` in a meaningful way.

The strongest reason is simple: the operations that were opened are not the likely moat.

OpenUSD already commoditizes the low-level ability to:

- inspect a stage
- create a prim
- set a transform
- manage references
- switch variants
- bind materials

What remains private is still the commercially defensible layer:

- "do this correctly for a production workflow"
- "repair this stage for me"
- "package this for delivery"
- "fix these assets/textures/import edge cases"
- "run the pipeline logic and heuristics that save real time"

If opening generic scene operations were enough to cannibalize `Preflight`, then the moat would already have been too low-level to depend on.

Current business conclusion:

- The moat is still intact.
- The split is more legible to customers and contributors.
- The refactor increases strategic clarity rather than reducing it.

### 2. Open-Source / Community Evaluation

This is a significant improvement over the previous half-open state.

Before this work, `Deconstructed` looked open while still depending on private advanced modules for core paths. That creates low trust, poor onboarding, and limited outside contribution quality.

After this work:

- the package boundary is clearer
- a public build path exists
- generic scene operations are available in a real public module
- contributors can work against a truer dependency graph

This better matches the social contract of an open project.

However, this part is not complete:

- some phase-1 "drop" items are still present in open code
- the old `DeconstructedUSDPipeline` source was removed during cleanup, which reduces stale references to the retired advanced path
- the open-source story is better, but not yet fully simplified

Current community conclusion:

- Credibility improved materially.
- The repository is now much closer to honestly open.
- The remaining work is mostly release hygiene and maintenance guardrails, not unresolved boundary design.

### 3. Technical / Architecture Evaluation

Architecturally, this was the right move.

The most important technical win is that the public boundary now respects the real constraint:

- `USDInterop` exists because of Swift/C++ interop and package compilation realities
- `USDOperations` now gives apps a stable, typed, generic consumer surface inside that same boundary
- `USDTools` remains a higher-level private layer instead of being both "interop workaround bucket" and "product value layer"

That is a better separation of concerns than the previous layout.

The main technical caveat is that the public/private split is correct at the package level, but still somewhat blurry inside `DeconstructedUSDInterop`.

Today that file does both of these things:

- correctly bridge generic operations into `USDOperations`
- still host a large amount of app-specific RealityKit authoring logic

That is not a release blocker by itself, because app-specific open logic can remain open. But it means the architecture is only partially normalized.

Current technical conclusion:

- Package-level design: strong improvement
- Consumer boundary design: strong improvement
- Internal cleanup inside `Deconstructed`: still incomplete

### 4. Product / UX Evaluation

The practical product result is good:

- the app builds
- it works
- no obvious visual regression was observed

That matters more than architectural neatness by itself.

This also validates the central thesis of the refactor:

- the open/public editor path can function on top of generic operations
- the advanced private tooling was not required for every visible UI path

Current product conclusion:

- The split appears behaviorally viable.
- The direction is validated by working software, not just by theory.

### 5. Release / Operational Evaluation

This is the area that still needs the most discipline before a wider release.

Good signs:

- matching package versions were published
- `Preflight` was updated to the new graph
- local build verification succeeded after follow-up fixes

Remaining operational concerns:

- a post-tag local fix was required in `USDOperations` for the `UsdGeomXformCommonAPI.RotationOrder` binding mismatch
- that means the published `USDInterop` tag and the current local working state are not yet perfectly aligned until a follow-up release is cut
- `Preflight` declares `USDOperations` already, but does not yet consume it directly; that is acceptable, but it means the migration is still asymmetric
- historical references to the retired advanced path still exist in explicitly marked historical documents, which is acceptable but worth keeping intentional

Current operational conclusion:

- The direction is releaseable in principle.
- The main remaining blocker is release hygiene, especially the follow-up `USDInterop` release.

## What Worked Well

- The split avoided a fake "crippled Lite" product.
- The Swift/C++ package constraint was respected instead of ignored.
- `USDOperations` is small enough to be understandable.
- `USDTools` remains clearly valuable after the carve-out.
- `Deconstructed` gained a more truthful open-source dependency story.

## What Did Not Fully Match the Original Conservative Plan

### 1. "Drop from phase 1" was not fully enforced

The original conservative rule set said several RealityKit/component-authoring surfaces should be removed or disabled rather than forced through the new public split.

That did not fully happen.

Large sections of the app-specific component authoring surface still exist in open `Deconstructed` code. This is not necessarily wrong, but it means the implemented result is more "public generic split plus retained open app-specific logic" than "strictly trimmed phase 1".

### 2. `DeconstructedUSDPipeline` required explicit retirement

The public package path no longer depended on it, but it remained in source form until cleanup. Removing it was the correct move because it was dead code that still pointed contributors at the retired advanced path.

### 3. Cleanup mostly succeeded, but did not eliminate every historical reference

The active build path and active contributor documentation now align with the current split.

What remains are mostly clearly marked historical notes and archived context. That is acceptable, but it means "zero mentions of the old name anywhere in the repo" is no longer the right success criterion. The right criterion is that active code paths and active guidance are correct.

### 3. `Preflight` has declared but not yet meaningfully adopted `USDOperations`

This is acceptable for phase 1 because the primary goal was to unlock `Deconstructed`, not to rewrite `Preflight`. But it means the cross-repo convergence is still partial.

## What We Are Still Potentially Overlooking

### 1. Public API drift risk

Once `USDOperations` exists as a public consumer surface, it becomes easier to keep adding "just one more operation." That is the main long-term risk.

Rule that should remain in force:

- do not move something to `USDOperations` because it is generic in theory
- move it only if it is both generic and necessary for the open consumer path

### 2. Boundary backsliding risk

If future work starts placing workflow logic into `USDOperations` for convenience, the original value split will erode over time.

### 3. Naming and expectation risk

The package names are now cleaner than `Lite`, but contributors may still assume that `USDOperations` is the right place for any reusable USD logic. It is not. It is the place for reusable generic scene operations only.

### 4. Release mismatch risk

Because a follow-up local fix was needed after the first published tags, release management needs to ensure that the published versions match the known-good build state before any broader rollout.

## Current Judgment on `USDTools` Value

`USDTools` is still valuable after this refactor.

More strongly: the refactor clarified why it is valuable.

Before the split, `USDTools` was carrying some ambiguity:

- some real product value
- some packaging/interoperability burden
- some generic operations that arguably should not have been private

After the split, its remaining scope is more defensible:

- workflows
- diagnostics
- repair/surgery
- asset conversion
- packaging
- higher-level heuristics
- production-oriented authoring support

That is a healthier private layer than "everything advanced plus some generic basics because of history."

## Release Readiness Assessment

Concrete pass/fail release gate:

- [USDOperations-Release-Checklist.md](/Volumes/Plutonian/_Developer/Deconstructed/source/Deconstructed/Docs/USDOperations-Release-Checklist.md)

### Ready

- strategic direction
- package-boundary shape
- open-source narrative improvement
- preservation of product moat
- local behavioral viability
- published package versions: `USDInterop v0.1.13` includes `USDOperations` and the post-tag transform fix; both `Preflight` and `Deconstructed` now resolve it

### Not fully ready

- final cleanup of stale/deferred code paths in `Deconstructed`
- optional but recommended: remove unnecessary declared dependencies until they are actually used
- optional but recommended: strengthen guardrails in `USDInterop` itself so the split does not drift

## Recommended Next Steps

~~1. Cut a follow-up `USDInterop` release if needed so the published version includes the verified `USDOperations` fix, not just the local working tree.~~
**Done.** `USDInterop v0.1.13` now includes the post-tag transform fix, and both `Deconstructed` and `Preflight` resolve it.

2. Add a short architecture rule to docs and CI:
- `USDOperations` is only for generic scene operations needed by public consumers.
- `USDTools` remains the owner of workflow/value logic.

3. Clean the remaining stale references in `Deconstructed`:
- keep dead advanced-path source out of the active tree
- remove old comments/help text that still refer to the previous advanced path

4. Keep the retained RealityKit/component authoring surface in `DeconstructedUSDInterop` explicitly classified as open and app-local unless there is a future product decision to trim it

5. Keep `Preflight` on `USDTools` as the default value path, and only migrate overlapping reads/writes to `USDOperations` when there is a clear maintenance benefit.

## Note on `USDInterfaces` Scope

`USDInterfaces` (~920 lines) carries more weight than a minimal DTO module. It includes validation types (`USDFixAction`, `USDValidationIssue`, `USDValidationOutput`), RealityKit-specific types (`USDBehaviorInfo`, `USDTimelineInfo`, `USDAnchorInfo`), and `USDShaderValueType`.

This is not a problem today. Public vocabulary is not the same as public implementation — exposing the type system lets `Deconstructed` display validation results without implementing the validation engine.

However, this surface should be watched. If `USDInterfaces` slowly grows to encode all of Preflight's conceptual model, the public contract becomes a maintenance burden and an unintentional API commitment. The rule should be: add a type to `USDInterfaces` only when it is needed by a public consumer, not because it is generic in theory.

## Final Recommendation

Proceed with this direction.

Do not revert the split.

The refactor improved the architecture, improved the honesty of the open-source story, and did not damage the product moat.

The strategic decision is validated. The package boundary is correctly drawn. The published release is aligned.

The remaining work is cleanup and enforcement, not architecture:

- Keep stale advanced-path source out of the active tree
- Keep the RealityKit authoring surface clearly documented as open and app-local
- Add guardrails so `USDOperations` stays boring and generic over time
