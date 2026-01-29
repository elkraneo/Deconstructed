# Deconstructed

A macOS document-based application that reverse-engineers and clones [Reality Composer Pro](https://developer.apple.com/augmented-reality/reality-composer/)'s functionality for editing `.realitycomposerpro` package files.

## Purpose

Reality Composer Pro (RCP) is Apple's professional tool for creating 3D content and spatial experiences for visionOS and iOS. While powerful, its file format and package structure aren't officially documented. **Deconstructed** aims to:

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
| Document Model | Document-based app with `FileWrapper` |
| File Watching | FSEvents (macOS native API) |
| Swift Version | 6.2 with strict concurrency |

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
│       │   ├── DeconstructedModels/# JSON schema models
│       │   ├── ProjectBrowserFeature/  # File browser TCA feature
│       │   ├── ProjectBrowserClients/  # File watching, asset discovery
│       │   └── ProjectBrowserUI/   # SwiftUI views
│       └── Tests/
└── Deconstructed.xcodeproj/
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

## Blog Series

This project is documented in a series of articles exploring the reverse-engineering process:

1. **[Deconstructing Reality Composer Pro: Introduction](https://www.elkraneo.com/deconstructing-reality-composer-pro-intro/)**
   - Overview of the project goals and motivations
   - Initial exploration of the `.realitycomposerpro` format

2. **[Deconstructing Reality Composer Pro: Document Type](https://www.elkraneo.com/deconstructing-reality-composer-pro-document-type/)**
   - Deep dive into the package structure
   - Understanding `main.json` and UUID mappings
   - Document-based app architecture with `FileWrapper`

## Development

### Requirements

- macOS 26.0+
- Xcode 26.2+
- Swift 6.2

### Building

```bash
# Build the Swift package
swift build --package-path Packages/DeconstructedLibrary

# Build the full Xcode project
xcodebuild -project Deconstructed.xcodeproj -scheme Deconstructed -destination 'platform=macOS' build
```

### Running

Open the built app or run from Xcode. The app registers itself as an editor for `.realitycomposerpro` files.

## License

TBD

## Acknowledgments

- Apple's Reality Composer Pro team (for the inspiration)
- [The Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture) by Point-Free
