# SwiftUsdShell Productivity Validation

## Overview

This document validates how **SwiftUsdShell** helps productivize OpenUSD development in Deconstructed. By providing a pure Swift facade over USDInterop, the shell enables safer, more maintainable, and more productive USD workflows.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Deconstructed App                             │
│  (SceneGraphUI, InspectorUI, ViewportUI, etc.)                      │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    SwiftUsdShell (Pure Swift)                        │
│  - USDStageHandle, USDPrimHandle                                     │
│  - USDPath, USDToken, USDAssetPath                                   │
│  - USDPrimSummary, USDPrimTree, USDStageMetadata                     │
│  - USDMaterialEditRequest, USDMaterialEditResult                     │
│  All types: Sendable, Hashable, Codable                               │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│              DeconstructedShellRuntime (C++ Interop)                 │
│  - Maps USDOperations types to SwiftUsdShell types                   │
│  - Provides openStage(), closeStage(), primSummary(), etc.           │
│  - Manages stage handle cache                                        │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    USDOperations (C++ Interop)                       │
│  - USDOperationsClient                                                │
│  - Direct OpenUSD access                                              │
│  - Unsafe C++ types                                                  │
└─────────────────────────────────────────────────────────────────────┘
```

## Productivity Benefits

### 1. Pure Swift Types, No C++ Interop at Call Site

**Before:**
```swift
// Every module that needs USD must import C++ interop
import USDInteropCxx
import OpenUSD

// Unsafe, cannot cross actor boundaries
let stage = pxr.UsdStage.Open(std.string(url.path), .LoadAll)
let prim = stage.GetPrimAtPath(SdfPath(std.string(path)))

// No type safety - strings everywhere
let materialPath = "/Root/Looks/Material1"
let channel = "diffuseColor" // Typos possible!
```

**After:**
```swift
// Import only pure Swift types
import SwiftUsdShell
import DeconstructedShellRuntime

// Safe, Sendable, can cross actor boundaries
let handle = try DeconstructedShellRuntime.openStage(at: url)
let summary = DeconstructedShellRuntime.primSummary(
	url: url,
	primPath: "/Root/Cube1"
)

// Type-safe enums prevent typos
let channel: USDMaterialEditableChannelID = .diffuseColor
```

### 2. Sendable Types for Concurrency

**Before:**
```swift
// Cannot send USD objects across actors
actor InspectorModel {
	var stage: pxr.UsdStage? // Error: Non-Sendable type
}
```

**After:**
```swift
// All shell types are Sendable
actor InspectorModel {
	var primSummary: USDPrimSummary? // ✅ Sendable
	var metadata: USDStageMetadata?  // ✅ Sendable
	var tree: USDPrimTree?           // ✅ Sendable
}
```

### 3. Codable for Serialization

**Before:**
```swift
// No built-in serialization for USD objects
// Must manually implement encoding/decoding
```

**After:**
```swift
// All types are Codable out of the box
let summary = USDPrimSummary(
	path: "/Root/Cube1",
	name: "Cube1",
	typeName: "Cube",
	isActive: true
)

// Serialize for persistence or network transmission
let data = try JSONEncoder().encode(summary)
let restored = try JSONDecoder().decode(USDPrimSummary.self, from: data)
```

### 4. Type-Safe Enums for Options

**Before:**
```swift
// String-based options, error-prone
let channel = "diffuseColor"  // Could be typo
let operation = "setTexture"  // Could be typo
```

**After:**
```swift
// Enum-based options, compiler-verified
let channel: USDMaterialEditableChannelID = .diffuseColor
let operation = USDMaterialEditOperation.setTexture(
	sourceURL: USDStageURL(textureURL),
	authoredAssetPath: "../textures/texture.png"
)
// .clearTexture
// .setValue(.scalar(0.5))
// .clearValue
```

### 5. Stable Handles for Resource Management

**Before:**
```swift
// Direct object references, complex lifecycle
var stages: [URL: pxr.UsdStage] = [:]
// Must manually manage C++ object lifetimes
// No way to serialize stage references
```

**After:**
```swift
// Stable handles that can be serialized
let handle = USDStageHandle(rawValue: 42)
let primHandle = USDPrimHandle(
	stage: handle,
	path: "/Root/Cube1"
)

// Can persist handles and reconstruct stages later
let encoded = try JSONEncoder().encode(handle)
```

### 6. Self-Documenting Request/Response Types

**Before:**
```swift
// Ad-hoc function parameters
func setMaterialTexture(
	url: URL,
	materialPath: String,
	channel: String,
	textureURL: URL,
	authoredPath: String?,
	policy: String
) throws {
	// What are valid channel values?
	// What are valid policy values?
	// What happens on success/failure?
}
```

**After:**
```swift
// Structured request types document themselves
let request = USDMaterialEditRequest(
	stageURL: USDStageURL(url),
	materialPath: "/Root/Looks/Material1",
	channel: .diffuseColor, // Compiler shows all valid options
	operation: .setTexture(
		sourceURL: USDStageURL(textureURL),
		authoredAssetPath: "../textures/texture.png"
	),
	policy: .preserveAuthoredMode // Compiler shows all valid options
)

let prepared = DeconstructedShellRuntime.prepareMaterialEdit(request: request)
#expect(prepared.readiness == .fullySupported) // Clear result type
```

## Validation Test Coverage

The `DeconstructedShellRuntimeTests` target validates:

### Type Safety
- ✅ Handles are hashable and codable
- ✅ Stage URLs standardize paths
- ✅ Paths and tokens support string literals
- ✅ Material edit contracts are fully codable

### Concurrency
- ✅ All shell types are Sendable
- ✅ Can share prim summaries across actor boundaries
- ✅ Stage handle cache is thread-safe

### Interoperability
- ✅ Opening stages produces valid handles
- ✅ Prim summaries contain expected attributes
- ✅ Stage metadata captures all properties
- ✅ Prim trees build hierarchical structures
- ✅ Material edit requests analyze branch plans

### Real-World Workflows
- ✅ Full scene round-trip (open → query → close)
- ✅ Scene graph navigation with traversal helpers
- ✅ Material edit preparation and execution
- ✅ Error handling with localized descriptions

## Migration Path for Deconstructed

### Phase 1: Shell Runtime (Current)
- ✅ Add SwiftUsdShell dependency
- ✅ Create DeconstructedShellRuntime bridge
- ✅ Add validation tests
- ✅ Document productivity benefits

### Phase 2: Incremental Adoption
- [ ] Update SceneGraphClients to use USDPrimTree instead of custom types
- [ ] Update InspectorModels to use USDStageMetadata
- [ ] Add material editing UI using USDMaterialEditRequest
- [ ] Refactor component authoring to use shell types

### Phase 3: Direct Shell Usage
- [ ] Phase out direct USDInterop dependencies from UI layers
- [ ] Use SwiftUsdShell types throughout the app
- [ ] Keep DeconstructedShellRuntime as the single interop point

## Comparison Summary

| Aspect | Before (USDInterop) | After (SwiftUsdShell) |
|--------|---------------------|----------------------|
| **Type Safety** | String-based options | Type-safe enums |
| **Concurrency** | Non-Sendable types | All types Sendable |
| **Serialization** | Manual implementation | Codable built-in |
| **Actor Isolation** | Requires @unchecked | Natural Sendable |
| **API Stability** | Changes with OpenUSD | Stable Swift facade |
| **Compilation** | Slow (C++ interop) | Fast (pure Swift) |
| **Testing** | Requires real USD files | Mock-friendly pure types |

## Conclusion

SwiftUsdShell provides significant productivity improvements for OpenUSD development in Deconstructed:

1. **Safer Code**: Type-safe enums prevent common errors
2. **Better Concurrency**: Sendable types enable clean actor isolation
3. **Easier Testing**: Pure Swift types can be easily mocked
4. **Faster Builds**: Less C++ interop at call sites
5. **Stable API**: Facade protects from OpenUSD version changes
6. **Self-Documenting**: Request/response types clearly express intent

The validation tests confirm that the shell types work as expected and provide real value for a production USD editor application.
