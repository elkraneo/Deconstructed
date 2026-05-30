# Deconstructed - Agent Instructions

## Critical Constraints

**macOS 26 (Tahoe) ONLY.** This is non-negotiable.

- No iOS, iPadOS, visionOS, watchOS, tvOS
- No backwards compatibility (no macOS 15, 14, etc.)
- No `#available` checks or `@available` attributes
- No multi-platform conditionals

### Forbidden APIs (iOS-only, do not use)

- `DocumentGroupLaunchScene`
- `DocumentLaunchView`
- `UIKit` anything
- Any API marked "iOS only" or "iPadOS only" in documentation

### Required APIs (use these)

- `AppKit` / `NSApplication` / `NSWindow` for macOS-specific needs
- `SwiftUI` with macOS idioms (Window scenes, Settings scenes, NSOpenPanel)
- Swift 6.2 concurrency (MainActor isolation by default)
- TCA 1.23.1 modern patterns: `@ObservableState`, `StoreOf`, `@Bindable` (no `WithViewStore`)
- On macOS 26, Observation is native; do not use `WithPerceptionTracking` unless targeting older OSes.

## Project Purpose

Reverse-engineer and clone Reality Composer Pro's functionality:
1. Open `.realitycomposerpro` package files
2. Parse and display project structure
3. Edit scenes and assets
4. Save changes back to the package format

## Dependency Resolution: Workspace vs Package.swift

### The Problem

This project has a split identity:
- **Public open-source repo** (`Deconstructed`) — anyone should be able to clone and build
- **Local first-party USD checkouts** (e.g. `SwiftUsd`, `SwiftUsdShell`) — may exist locally and be wired through the workspace for internal work, but the public build resolves them from the binary distribution

The root `Package.swift` and inner `Packages/DeconstructedLibrary/Package.swift` declare remote URLs for CI/public consumption. But locally, Xcode resolves dependencies at the **workspace level**, overriding what `Package.swift` says.

### How It Actually Works

**All dependency resolution happens through `Deconstructed.xcworkspace`.** The workspace includes local package references that Xcode prefers over remote URLs with the same identity.

This means:
- `Package.swift` remote URLs are **fallbacks for CI / clean clones only**
- The inner `DeconstructedLibrary/Package.swift` may reference `branch: "main"` or pinned revisions — **it doesn't matter locally** because the workspace overrides them
- Editing local first-party package checkouts such as `/Volumes/Plutonian/_Developer/SwiftUsdShell` compiles immediately when the workspace is configured to use them
- **You must open `Deconstructed.xcworkspace`**, not the `.xcodeproj`

### Do NOT Try to Build via `swift build` in Inner Package

Running `swift build` inside `Packages/DeconstructedLibrary/` will fail because:
1. SwiftPM resolves deps from `Package.swift` directly (no workspace override)
2. The inner package may point to `branch: "main"` while root pins a revision — SwiftPM cannot reconcile two different revision-based requirements for the same package
3. Local-only packages (like `SelectionOutline` as a sibling) resolve fine, but remote deps conflict

**Always build through Xcode workspace or from the root `Package.swift`:**
```bash
# From repo root — uses root Package.swift which is kept CI-safe
swift build --target ViewportUI
```

### For Agents / CI

- The root `Package.swift` is the source of truth for public/CI builds
- It pins stable versions of remote deps (revisions or semver)
- Local packages (`SelectionOutline`, etc.) use relative paths that work from root
- Never edit the inner `DeconstructedLibrary/Package.swift` dependency URLs to match root — they serve different purposes

## USD Boundary

The target split is:

- pure-Swift contract boundary: `SwiftUsdShell` (consumed as a binary)
- OpenUSD-backed runtime adapter: `SwiftUsdShellOpenUSD` / `OpenUSDStageRuntime` (binary), driven by the app-local `DeconstructedShellRuntime`
- app-local runtime adapter and open RCP `.usda` authoring: `DeconstructedUSDInterop`
- **archived, out of the build graph — do not reintroduce:** `USDInterop`, `USDInterfaces`, `USDInteropCxx`, `USDOperations`, `USDTools`, `USDInteropAdvanced-binaries`

Rules:

- product-facing USD DTOs and generic edit contracts go in `SwiftUsdShell`; add to it only when shapes are equivalent or an explicit converter exists
- `SwiftUsdShell` is not a runtime; do not use it to claim file loading, rendering, validation, or repair behavior
- generic scene reads/writes go through `OpenUSDStageRuntime` (via `DeconstructedShellRuntime`); `.usda` text authoring stays in `DeconstructedUSDInterop`
- workflows, diagnostics, repair, packaging, conversion, and heuristics belong in the app/domain layer, not in `SwiftUsdShell` or the runtime adapter
- do not reintroduce dependencies on the archived legacy modules

See `Docs/SwiftUsdShell-Boundary-Manifesto.md` before changing USD package dependencies or migrating DTOs.

## Shell-Runtime Dependency Installation

This is a recurring footgun. Read this section before adding any new `@Dependency`-backed client that lives behind the SwiftUsdShell boundary.

### The pattern

Targets that do not link OpenUSD (e.g. `InspectorShellFeature`, `SceneGraphFeature`) declare a `DependencyKey` whose `liveValue` is a **safe stub**:

- `SceneInspectorClient.liveValue` returns empty data (`{ _ in [] }`, etc.)
- `SceneEditClient.liveValue` throws `runtimeUnavailable`

The real OpenUSD-backed implementation lives in `DeconstructedShellRuntime` as a `static let live` extension (e.g. `SceneInspectorClient+Live.swift`, `SceneEditClient+Live.swift`). It is installed at app startup by `AppFeature.liveDependenciesInstalled`:

```swift
private static let liveDependenciesInstalled: Bool = {
    prepareDependencies {
        $0.sceneInspector = .live
        $0.sceneEditClient = .live
        // ← add new shell-runtime clients HERE
    }
    return true
}()
```

### The footgun

If you add a new shell-runtime client (interface in a non-Cxx target + `+Live.swift` in `DeconstructedShellRuntime`) and forget to wire `prepareDependencies`, the app will silently use the stub:

- A stub that **throws** surfaces as a user-visible error ("OpenUSD scene editing runtime is not available.") — that's how the SceneEditClient bug was found.
- A stub that **no-ops** is worse: writes appear to succeed, reads return empty data, and the bug looks like "the inspector is broken" rather than "the dependency isn't installed."

### The rule

When you add a new client following the SwiftUsdShell pattern:

1. Define the interface + safe stub `liveValue` in the shell-feature target. Prefer **throwing** stubs over **silently empty** ones — the runtime will fail loudly when the install is missed.
2. Add a `+Live.swift` adapter in `DeconstructedShellRuntime` that exposes a `static let live` (or `static var live`).
3. **Install it in `AppFeature.liveDependenciesInstalled`.** Same commit as steps 1–2.
4. Reference this section in the client's `liveValue` docstring so anyone tracing "why is data empty?" finds the install requirement.

Use `static var` computed properties for `liveValue` / `testValue` / `previewValue` (per pfw-dependencies guidance), not `static let`.

Never put a client behind `@Dependency` whose live implementation requires Cxx but whose `liveValue` is reached at runtime — that's the exact stub-failure trap.

## Reference Implementation

Analyze this real RCP project for format details:
```
/Volumes/Plutonian/_Developer/Deconstructed/references/Base
```

**IMPORTANT**: The document is the **`.realitycomposerpro` bundle**, NOT the parent folder. RCP creates an SPM package wrapper around it for Xcode/Swift integration.

### Package Structure
```
Base/                                      # SPM package (wrapper for integration)
├── Package.swift                          # SPM manifest
├── Package.realitycomposerpro/            # <- THE DOCUMENT (what we open/save)
│   ├── ProjectData/
│   │   └── main.json                      # UUID mappings (paths reference ../Sources/)
│   ├── WorkspaceData/
│   │   ├── Settings.rcprojectdata         # Editor settings (JSON)
│   │   ├── SceneMetadataList.json         # Hierarchy state
│   │   └── <username>.rcuserdata          # Per-user prefs
│   ├── Library/
│   └── PluginData/
└── Sources/                               # Assets (sibling to document)
    └── <ProjectName>/
        ├── <ProjectName>.swift            # Bundle accessor
        └── <ProjectName>.rkassets/
            └── Scene.usda                 # USD scene files
```

### Key Insight
- Double-clicking `.realitycomposerpro` opens RCP
- RCP does NOT display the parent folder structure
- Asset paths in `main.json` like `/Base/Sources/Base/Base.rkassets/Scene.usda` navigate relative to SPM root

## Source of Truth: Filesystem vs main.json

### The Problem

`main.json` contains `pathsToIds` mapping scene file paths to UUIDs. However, RCP treats this as a **loose index**, not a strict manifest:

- **Stale entries persist**: Deleted/renamed files keep their old entries
- **Duplicates exist**: Same file may appear with different path formats and different UUIDs
- **Path formats are inconsistent**: Mix of `/Project/Sources/...`, `Project/Sources/...`, `/Sources/...`
- **Percent-encoding varies**: Some paths have `%20` for spaces, others don't

Example from a real project:
```json
{
  "/MyProject/Sources/MyProject/MyProject.rkassets/Scene.usda": "UUID-1",
  "MyProject/Sources/MyProject/MyProject.rkassets/Scene.usda": "UUID-2",
  "/Sources/MyProject/MyProject.rkassets/Deleted.usda": "UUID-3"
}
```

### Our Architecture Decision

**Filesystem is the source of truth for what exists. `main.json` is a best-effort UUID lookup.**

#### Asset Discovery (`AssetDiscoveryClient`)

1. Scan `Sources/` directory on disk to find `.rkassets`
2. Recursively enumerate actual files/folders
3. Consult `main.json` only for UUID assignment (optional, gracefully handles missing)

```swift
// Find .rkassets by scanning disk, not parsing main.json paths
private func findRKAssets(in sourcesURL: URL) -> URL? {
    // Scan Sources/<ProjectName>/<ProjectName>.rkassets
}

// UUID lookup is best-effort
private func loadSceneUUIDLookup(documentURL: URL) -> [String: String] {
    // Returns empty dict if main.json unreadable - discovery still works
}
```

#### File Operations

When moving/renaming files:
1. Perform filesystem operation first (`FileManager.moveItem`)
2. Update `main.json` path mappings to match new locations
3. Re-scan filesystem to rebuild asset tree

This ensures the UI always reflects actual disk state, even if `main.json` gets out of sync.

#### Why RCP Keeps Stale Entries

Inferred reasons (not from Apple docs):
- **Undo/history support**: Old UUIDs preserved for potential restoration
- **Reference stability**: External links to scenes by UUID survive renames
- **Collaboration**: Merging projects with different rename histories
- **Lazy cleanup**: No benefit to aggressive pruning

### Implications for Deconstructed

1. **Never trust `main.json` for file existence** - always verify on disk
2. **Generate stable IDs from paths** - `AssetItem.stableID(for:)` uses MD5 of path
3. **Handle missing UUIDs gracefully** - new files may not be in `main.json` yet
4. **Update `main.json` on moves/renames** - keep it roughly in sync for RCP compatibility
5. **Don't prune stale entries** - match RCP's behavior for interoperability

### Change Detection

`AssetItem.Equatable` must compare more than just `id`:

```swift
public static func == (lhs: AssetItem, rhs: AssetItem) -> Bool {
    lhs.id == rhs.id
    && lhs.name == rhs.name
    && lhs.children == rhs.children  // Critical for tree updates
}
```

Since `stableID` is path-based, a folder's ID stays constant even when children change. Without comparing `children`, SwiftUI/TCA won't detect tree structure changes after file moves.

## Technical Stack

| Component | Choice |
|-----------|--------|
| UI Framework | SwiftUI (macOS 26) |
| App Architecture | Document-based (`DocumentGroup`, `FileDocument`) |
| Document Type | `.realitycomposerpro` bundle via `FileWrapper` |
| UTType | `com.apple.realitycomposerpro` (imported) |
| Swift Version | 6.2 with strict concurrency |
| Min Deployment | macOS 26.0 only |

## Source Files

| File | Purpose |
|------|---------|
| `DeconstructedApp.swift` | App entry point, scene declarations |
| `Packages/DeconstructedLibrary/Sources/RCPDocument/DeconstructedDocument.swift` | FileDocument conformance for packages |
| `Packages/DeconstructedLibrary/Sources/DeconstructedModels/ProjectModels.swift` | Codable structs matching RCP JSON schemas |
| `Packages/DeconstructedLibrary/Sources/DeconstructedUI/ContentView.swift` | Main document editing interface |
| `Packages/DeconstructedLibrary/Sources/DeconstructedFeatures/LaunchExperience.swift` | Welcome window UI + recent projects |
| `Packages/DeconstructedLibrary/Sources/DeconstructedClients/NewProjectCreator.swift` | New project scaffolding + open workflow |

## Before Writing Code

1. Check if the API exists on macOS (not just iOS)
2. Use the latest macOS 26 APIs without guards
3. Reference the actual RCP package structure above
4. Keep the document-based architecture intact
