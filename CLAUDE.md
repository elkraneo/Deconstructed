# Deconstructed

A **macOS 26 (Tahoe) only** application. No iOS, no visionOS, no backwards compatibility.

## Goal

Clone of Reality Composer Pro that can open, edit, and save `.realitycomposerpro` package files.

## Platform Constraints

- **macOS 26+ only** - use the latest APIs without version checks
- No `#available`, no `if #available`, no iOS/visionOS conditionals
- No iOS-only APIs (`DocumentGroupLaunchScene`, `DocumentLaunchView`, etc.)
- Swift 6.2 with strict concurrency (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`)

## Reference Materials

```
/Volumes/Plutonian/_Developer/Deconstructed/references/Base
```

Real RCP project structure. **The document is the `.realitycomposerpro` bundle**, not the parent folder. RCP creates an SPM package wrapper for integration:

```
Base/                              <- SPM package (created by RCP for integration)
├── Package.swift
├── Package.realitycomposerpro/    <- THE DOCUMENT (this is what we open/save)
│   ├── ProjectData/
│   │   └── main.json              <- path-to-UUID mappings (paths reference ../Sources/)
│   ├── WorkspaceData/
│   │   ├── Settings.rcprojectdata
│   │   ├── SceneMetadataList.json
│   │   └── *.rcuserdata
│   ├── Library/
│   └── PluginData/
└── Sources/                       <- Assets (sibling to document, referenced by main.json)
    └── <Name>/
        ├── <Name>.swift
        └── <Name>.rkassets/
            └── Scene.usda
```

## Architecture

- Document = `.realitycomposerpro` bundle (FileDocument + FileWrapper)
- UTType: `com.apple.realitycomposerpro` (imported)
- On "New Project": create document + generate surrounding SPM package
- Asset paths in `main.json` are relative to SPM package root (sibling navigation)

## USD Boundary

The USD stack is built on SwiftUsdShell. The migration off the legacy
`USDInterop` family is complete; those packages are archived and out of the
build graph.

- `SwiftUsdShell` is the pure-Swift contract boundary (DTOs, requests, results). No C++ types cross it.
- `SwiftUsdShellOpenUSD` (`OpenUSDStageRuntime`) is the mechanical OpenUSD-backed runtime adapter. Both are consumed as binaries via `SwiftUsd-binaries` + `SwiftUsdShell-binaries`.
- `DeconstructedShellRuntime` is the app-local runtime layer that drives `OpenUSDStageRuntime` and maps results to SwiftUsdShell DTOs. It is the only place that needs Cxx/OpenUSD via the binary slice.
- `DeconstructedUSDInterop` is the app-local adapter and open RCP `.usda` text-authoring layer. It stays.
- **Archived — do not reintroduce:** `USDInterop`, `USDInterfaces`, `USDInteropCxx`, `USDOperations` (the legacy runtime family) and `USDTools` / `USDInteropAdvanced-binaries` (the private advanced layer). No target may depend on them.

For the rationale and the completed migration record, see:

- `Docs/SwiftUsdShell-Boundary-Manifesto.md`
- `Docs/SwiftUsdShell-Migration-Regression-Ledger.md`
- `Docs/USDInterop-Sunset-Migration.md` (migration complete)

Rule of thumb:

- feature-facing contracts live in `SwiftUsdShell`; add to it only with explicit semantic equivalence or converters
- `SwiftUsdShell` is a contract, not a runtime — do not document it as file loading, rendering, validation, or repair infrastructure
- generic scene reads/writes go through `OpenUSDStageRuntime` (in `DeconstructedShellRuntime`); `.usda` text authoring stays in `DeconstructedUSDInterop`
- workflows, heuristics, packaging, conversion, and repair belong in the app/domain layer, not in `SwiftUsdShell` or the runtime adapter
- do not reintroduce dependencies on the archived legacy modules

## Shell-Runtime Dependency Installation

Any `@Dependency`-backed client whose live implementation lives in `DeconstructedShellRuntime` (because it needs Cxx/OpenUSD) MUST be installed in `AppFeature.liveDependenciesInstalled` via `prepareDependencies`. The `liveValue` defined in the shell-feature target is a stub.

If the install is missed, the stub silently no-ops (or throws `runtimeUnavailable`), and writes appear to succeed while reads return empty data. This has bitten us twice (SceneInspectorClient, SceneEditClient). Prefer **throwing** stubs over no-op stubs so the failure surfaces loudly.

When adding a new client following this pattern, the install line in `AppFeature` belongs in the same commit as the `+Live.swift` adapter. See `AGENTS.md` § "Shell-Runtime Dependency Installation" for the full pattern.

## Key Files

- `DeconstructedApp.swift` - App entry, scenes
- `DeconstructedDocument.swift` - FileDocument for .realitycomposerpro packages
- `ProjectModels.swift` - Codable models matching RCP's JSON schemas
- `ContentView.swift` - Main document editor view
- `UI/LaunchExperience.swift` - Welcome window (macOS Window scene)
