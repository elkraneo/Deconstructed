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
