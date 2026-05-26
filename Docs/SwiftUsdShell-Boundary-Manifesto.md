# SwiftUsdShell Boundary Manifesto

This document defines how Deconstructed should use `SwiftUsdShell` as the public USD contract boundary.

## Position

`SwiftUsdShell` is the pure-Swift contract package for USD-facing data and edit requests. It is allowed in public, product-facing Deconstructed modules because consumers can read those types without importing SwiftUsd, OpenUSD, Swift/C++ interop modules, or private workflow packages.

`SwiftUsdShell` is not a USD runtime. It does not promise to open, render, validate, repair, or rewrite USD files by itself. Runtime behavior still belongs behind implementation modules that can depend on OpenUSD-backed packages.

## Correct Use

Deconstructed should use `SwiftUsdShell` for:

- neutral USD DTOs shared across app features
- generic edit request/result contracts
- public client protocols whose callers should not know about OpenUSD
- tests that assert public contracts without loading the C++ runtime

Deconstructed should not use `SwiftUsdShell` for:

- Reality Composer Pro workflow heuristics
- product-specific repair, conversion, packaging, or validation policy
- OpenUSD handles, `VtValue`, `SdfPath`, `UsdStage`, or Swift/C++ typed helpers
- a substitute for the runtime implementation layer

## Runtime Boundary

The current runtime boundary remains intentionally split:

- `SwiftUsdShell`: pure-Swift public contracts
- `USDInterop` / `USDOperations` / `USDInterfaces`: transitional public OpenUSD-backed runtime and DTO surface currently used by Deconstructed
- `DeconstructedUSDInterop`: app-local runtime adapter and RCP-specific open authoring logic
- `USDTools`: private/internal workflow and value layer, not required by the public Deconstructed build path

The intended direction is to move product-facing DTOs and client contracts toward `SwiftUsdShell` when the shapes are equivalent or a deliberate converter exists. Do not blanket-replace `USDInterfaces` types just because a similarly named shell type exists.

## Current Status

As of 2026-04-28, Deconstructed still imports `USDInterfaces`, `USDOperations`, and `USDInterop` directly for its working runtime path. That is acceptable only as a transition state. It proves the public build is not using private `USDTools`, but it does not yet prove full SwiftUsdShell adoption.

The next correct proof point is a small, explicit migration:

1. Add `SwiftUsdShell` as a direct public dependency.
2. Move one neutral app-facing contract to a shell type.
3. Keep conversion from legacy `USDInterfaces` inside `DeconstructedUSDInterop` or another runtime adapter.
4. Verify no app feature imports OpenUSD, `USDInteropCxx`, or `USDTools`.

## Guardrails

Code review should reject:

- importing `USDTools` or `USDTools*` from public Deconstructed targets
- exposing OpenUSD or Swift/C++ interop types in public app-facing APIs
- putting RCP workflow decisions into `SwiftUsdShell`
- adding shell runtime claims to README or user-facing docs
- migrating DTOs without checking semantic equivalence

Code review should accept:

- feature modules depending on `SwiftUsdShell` for neutral contract types
- runtime adapters converting shell contracts to OpenUSD-backed implementation calls
- app-local RCP authoring logic that remains open in `DeconstructedUSDInterop`
- gradual removal of `USDInterfaces` imports when each replacement is explicit and tested

## Practical Test

The public architecture is correct when a feature can express what it wants in pure Swift, while only the runtime adapter knows how that request becomes OpenUSD work.

In code shape, that means:

```text
Feature/UI -> SwiftUsdShell contracts -> DeconstructedUSDInterop adapter -> USD runtime
```

and not:

```text
Feature/UI -> OpenUSD / USDInteropCxx / USDTools
```

