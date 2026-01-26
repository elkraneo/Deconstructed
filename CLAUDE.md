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

## Key Files

- `DeconstructedApp.swift` - App entry, scenes
- `DeconstructedDocument.swift` - FileDocument for .realitycomposerpro packages
- `ProjectModels.swift` - Codable models matching RCP's JSON schemas
- `ContentView.swift` - Main document editor view
- `UI/LaunchExperience.swift` - Welcome window (macOS Window scene)
