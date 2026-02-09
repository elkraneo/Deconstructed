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
- **Private dependencies** (`USDInteropAdvanced` source) — only available locally

The root `Package.swift` and inner `Packages/DeconstructedLibrary/Package.swift` declare remote URLs for CI/public consumption. But locally, Xcode resolves dependencies at the **workspace level**, overriding what `Package.swift` says.

### How It Actually Works

**All dependency resolution happens through `Deconstructed.xcworkspace`.** The workspace includes local package references that Xcode prefers over remote URLs with the same identity.

This means:
- `Package.swift` remote URLs are **fallbacks for CI / clean clones only**
- The inner `DeconstructedLibrary/Package.swift` may reference `branch: "main"` or pinned revisions — **it doesn't matter locally** because the workspace overrides them
- Editing `/Volumes/Plutonian/_Developer/USDInteropAdvanced` compiles immediately
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
