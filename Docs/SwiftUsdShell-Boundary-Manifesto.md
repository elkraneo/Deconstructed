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

The runtime boundary is:

- `SwiftUsdShell`: pure-Swift public contracts (binary)
- `SwiftUsdShellOpenUSD` / `OpenUSDStageRuntime`: mechanical OpenUSD-backed runtime adapter (binary), driven by the app-local `DeconstructedShellRuntime`
- `DeconstructedUSDInterop`: app-local runtime adapter and RCP-specific open `.usda` authoring logic
- archived, out of the build graph: `USDInterop`, `USDOperations`, `USDInterfaces`, `USDInteropCxx`, `USDTools`, `USDInteropAdvanced-binaries`

Product-facing DTOs and client contracts are expressed in `SwiftUsdShell`. When a new contract is needed, add it to the shell only when shapes are equivalent or a deliberate converter exists.

## Current Status

As of 2026-05-30, the migration off the legacy `USDInterop` family is complete. No compiled Deconstructed source imports `USDInterfaces`, `USDOperations`, `USDInterop`, `USDInteropCxx`, or `USDTools`; the runtime path is `SwiftUsdShell` + `SwiftUsdShellOpenUSD` (binaries) through `DeconstructedShellRuntime`, with `.usda` text authoring in `DeconstructedUSDInterop`. The legacy packages are archived on GitHub.

See `Docs/USDInterop-Sunset-Migration.md` for the migration record and `Docs/SwiftUsdShell-Migration-Regression-Ledger.md` for the parity assessment of the remaining non-blocking gaps.

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
- keeping the build graph free of the archived legacy modules (`USDInterop`, `USDOperations`, `USDInterfaces`, `USDInteropCxx`, `USDTools`)

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

