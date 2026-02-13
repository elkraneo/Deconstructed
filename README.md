# Deconstructed
![Deconstructed app interface with multiple scene tabs open. A Bunsen burner model is selected in the scene hierarchy and displayed in the 3D viewport alongside a gray sphere with transform gizmos visible. The right inspector panel shows Transform properties (Position, Rotation, Scale), Material Bindings, Variants, and References sections. The bottom Project Browser displays asset thumbnails including the BunsenBurner.usdz file, scenes, and primitive shapes.](./assets/preview.png)
A macOS document-based application that reverse-engineers and clones [Reality Composer Pro](https://developer.apple.com/augmented-reality/reality-composer/)'s functionality for editing `.realitycomposerpro` package files.

> [!IMPORTANT]
> **Open development status:** Deconstructed is developed in the open, and this repository contains the active source code.
> We are still finishing fully reproducible fresh-clone builds while parts of the lower-level USD/C++ interop toolchain are being stabilized.
> In the meantime, download the latest packaged macOS app from [Latest Release](https://github.com/elkraneo/Deconstructed/releases/latest).
> For source builds, follow the setup notes in [Local Development (CI-Safe)](#local-development-ci-safe).

## Purpose

[Reality Composer Pro](https://developer.apple.com/documentation/realitycomposerpro) (RCP) is Apple's professional tool for creating 3D content and spatial experiences for visionOS and iOS. While powerful, its file format and package structure aren't officially documented. **Deconstructed** aims to:

1. **Open** `.realitycomposerpro` package files
2. **Parse** and display the project structure
3. **Edit** scenes and assets through a native macOS interface
4. **Save** changes back to the package format

## Technical Stack

| Component | Technology |
|-----------|------------|
| Platform | macOS 26 (Tahoe) only |
| UI Framework | SwiftUI |
| Architecture | The Composable Architecture (TCA) 1.23.1 |
| Document Model | SwiftUI `DocumentGroup` + `FileDocument` (`FileWrapper`-backed `RCPPackage`) |
| File Watching | FSEvents (macOS native API) |
| 3D Viewport | `RealityKitStageView` (StageView) + USD (Swift/C++ interop) |
| Swift Version | 6.2 with strict concurrency |

### External Dependencies

- **[swift-composable-architecture](https://github.com/pointfreeco/swift-composable-architecture)** - App architecture and reducer composition
- **[swift-sharing](https://github.com/pointfreeco/swift-sharing)** - Shared state helpers used by feature modules
- **[USDInterop](https://github.com/Reality2713/USDInterop)** - Swift bindings for OpenUSD
- **[USDInteropAdvanced](https://github.com/Reality2713/USDInteropAdvanced)** / **[USDInteropAdvanced-binaries](https://github.com/Reality2713/USDInteropAdvanced-binaries)** - Higher-level USD operations
- **[StageView](https://github.com/reality2713/StageView)** - RealityKit-backed viewport integration

## Local Development (CI-Safe)

This repository has a split dependency setup:

- Root `Package.swift` is the source of truth for public/CI-safe builds.
- Xcode resolves dependencies through `Deconstructed.xcworkspace`, which can override remotes with local package references.
- The inner `Packages/DeconstructedLibrary/Package.swift` exists for package modularization but should not be used directly for local `swift build`.

1. Open `/Volumes/Plutonian/_Developer/Deconstructed/source/Deconstructed/Deconstructed.xcworkspace` (not the `.xcodeproj`).
2. (Optional) Install SwiftPM mirrors if you want URL-based dependencies redirected to local checkouts:
```sh
./Scripts/spm-mirrors/install.sh
```
3. If Xcode appears stuck on an old revision:
- Xcode: `File > Packages > Reset Package Caches`, then `File > Packages > Resolve Package Versions`
- Or delete DerivedData for this app
4. To return to pure-remote resolution:
```sh
./Scripts/spm-mirrors/uninstall.sh
```

## Project Structure

```
Deconstructed/
├── Deconstructed/                  # Main app target
│   ├── DeconstructedApp.swift      # App entry point
│   ├── Info.plist                  # Document type declarations
│   └── Assets.xcassets/
├── Packages/
│   └── DeconstructedLibrary/       # Swift Package with feature modules
│       ├── Sources/
│       │   ├── RCPDocument/        # FileDocument conformance
│       │   ├── DeconstructedModels/ # JSON schema models
│       │   ├── ProjectBrowserFeature/  # File browser TCA feature
│       │   ├── ProjectBrowserClients/  # File watching, asset discovery
│       │   ├── ProjectBrowserUI/   # SwiftUI views
│       │   ├── SceneGraphFeature/  # Scene hierarchy navigation
│       │   ├── SceneGraphClients/  # USD scene loading
│       │   ├── SceneGraphUI/       # Scene tree view
│       │   ├── ViewportModels/     # Viewport state models
│       │   ├── ViewportUI/         # 3D viewport (RealityKitStageView-based)
│       │   ├── InspectorFeature/   # Inspector TCA feature
│       │   ├── InspectorModels/    # Inspector data models
│       │   └── InspectorUI/        # Inspector panel views
│       └── Tests/
├── Deconstructed.xcodeproj/
└── Deconstructed.xcworkspace/      # Primary local entry point
```

## Document Format

The `.realitycomposerpro` document is a bundle (package) with this structure:

```
Package.realitycomposerpro/          # The document bundle
├── ProjectData/
│   └── main.json                    # UUID mappings for scenes
├── WorkspaceData/
│   ├── Settings.rcprojectdata       # Editor settings
│   ├── SceneMetadataList.json       # Hierarchy state
│   └── <user>.rcuserdata            # Per-user preferences
├── Library/                         # Asset library
└── PluginData/                      # Plugin-specific data

Sources/                             # Assets (sibling to document)
└── <ProjectName>/
    ├── <ProjectName>.swift          # Bundle accessor
    └── <ProjectName>.rkassets/      # Asset directory
        └── Scene.usda               # USD scene files
```

### Key Insight

The `.realitycomposerpro` bundle is the **document itself**, while the parent folder containing `Sources/` is the SPM package wrapper for Xcode integration. RCP treats `main.json` as a loose index - the filesystem is the source of truth for what exists.

## Architecture Decisions

### Filesystem as Source of Truth

`main.json` contains `pathsToIds` mappings, but it often has:
- Stale entries (deleted/renamed files keep old entries)
- Duplicates (same file with different path formats)
- Inconsistent percent-encoding

**Solution**: Always scan the filesystem for actual contents, use `main.json` only for UUID lookup (gracefully handling missing entries).

### File Watching

Uses **FSEvents** instead of `DispatchSource` because:
- Native recursive directory watching
- No need to manually watch each subdirectory
- File-level events with proper change types

Events are debounced (300ms) to prevent excessive UI reloads during batch operations.

### Inspector Architecture

The Inspector panel uses a **context-sensitive** approach:

- **Scene Layer Mode**: Shows USD stage metadata (default prim, meters per unit, up axis) when no prim is selected
- **Prim Mode**: Shows transform editing, material bindings, variant sets, and references when a node is selected in the Scene Navigator

State is synchronized via TCA's scoped reducers - DocumentEditorFeature wires the inspector to scene URL changes and selection updates from the Scene Navigator.

### USD Metadata Flow

Layer data is read from USD stage metadata via `USDAdvancedClient.stageMetadata()`:
- `upAxis`: "Y" or "Z" (normalized from TfToken values)
- `metersPerUnit`: Scene scale factor
- `defaultPrimName`: The default prim path

Available prims for the default prim dropdown are collected from the scene graph hierarchy and merged with the layer data once both streams converge.

## Blog Series

This project is documented in a series of articles exploring the reverse-engineering process:

1. **[Deconstructing Reality Composer Pro: Introduction](https://elkraneo.com/deconstructing-reality-composer-pro-intro/)**
   - Overview of the project goals and motivations
   - Initial exploration of the `.realitycomposerpro` format

2. **[Deconstructing Reality Composer Pro: Document Type](https://elkraneo.com/deconstructing-reality-composer-pro-document-type/)**
   - Deep dive into the package structure
   - Understanding `main.json` and UUID mappings
   - Document-based app architecture with `FileWrapper`

3. **[Deconstructing Reality Composer Pro: Project Browser](https://elkraneo.com/deconstructing-reality-composer-pro-project-browser/)**
   - Building the file browser with TCA
   - File watching with FSEvents
   - Asset discovery and tree management

4. **[Deconstructing Reality Composer Pro: Viewport](https://elkraneo.com/deconstructing-reality-composer-pro-viewport/)**
   - Integrating StageView/RealityKit for 3D rendering
   - Viewport toolbar and camera controls
   - Environment configuration

5. **[Deconstructing Reality Composer Pro: Scene Navigator](https://elkraneo.com/deconstructing-reality-composer-pro-scene-navigator/)**
   - Scene hierarchy visualization
   - USD prim navigation
   - Inserting primitives and structural elements

6. **[Deconstructing Reality Composer Pro: Inspector Basics](https://elkraneo.com/deconstructing-reality-composer-pro-inspector-basics/)**
   - Building the Inspector panel with TCA and scoped feature state
   - Wiring USD stage metadata (default prim, scale, up axis) into the UI
   - Establishing the selection-driven path toward prim-level inspection

7. **[Deconstructing Reality Composer Pro: Inspector Bindings, References, Variants](https://elkraneo.com/deconstructing-reality-composer-pro-inspector-bindings-references-variants/)**
   - Extending prim inspection with material bindings and relationship references
   - Implementing variant set discovery and selection workflows
   - Bridging inspector edits to live viewport and scene graph updates

## Notes

- `/Volumes/Plutonian/_Developer/Deconstructed/source/Deconstructed/Docs/MaterialX-Interchange.md` (MaterialX vs UsdPreviewSurface portability through RealityKit/RCP)

## Current Status

### Implemented Features

- ✅ **Document Handling**: Open and save `.realitycomposerpro` packages
- ✅ **Project Browser**: File tree with folder creation, file operations, and live watching
- ✅ **Scene Navigator**: Hierarchy view with prim selection and insertion
- ✅ **Viewport**: 3D preview with grid, axes, and environment controls
- ✅ **Inspector**: Layer Data, scene playback, transform editing, material bindings, references, and variants

### In Progress

- 🚧 **Component Management**: ECS component visualization and editing
- 🚧 **Material Editor**: Shader graph integration

## Development

### Requirements

- macOS 26.0+
- Xcode 26.2+
- Swift 6.2

### Building

```bash
# Build from repo root (CI-safe root manifest)
swift build --target ViewportUI

# Build the app through the workspace
xcodebuild -workspace Deconstructed.xcworkspace -scheme Deconstructed -destination 'platform=macOS' build
```

### Running

Open the built app or run from Xcode. The app registers itself as an editor for `.realitycomposerpro` files.

## License

TBD

## Acknowledgments

- Apple's Reality Composer Pro team (for the inspiration)
- [The Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture) by Point-Free
