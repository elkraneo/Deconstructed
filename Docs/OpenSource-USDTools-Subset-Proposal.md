# USDTools Open-Source Subset Proposal

> Historical note:
> This proposal predates the implemented `USDOperations` split and is kept for decision history.
> It is not the current architecture plan.
>
> Current decision records:
> - `Docs/USDOperations-Refactor-Evaluation.md`
> - `Docs/USDOperations-Release-Checklist.md`

## Executive Summary

This document analyzes what **Deconstructed** uses from **USDInteropAdvanced** (now **USDTools**) and proposes a strategy for creating an open-source subset that enables third-party developers to build and contribute to the project without giving away the proprietary value that USDTools provides to **Preflight**.

---

## Current Dependency Analysis

### Module Dependency Map

```
Deconstructed
├── DeconstructedUSDInterop (facade layer)
│   ├── USDInterop (public - basic read operations)
│   ├── USDInterfaces (public - DTOs/protocols)
│   ├── USDInteropCxx (public - C++ interop)
│   ├── USDInteropAdvancedCore (proprietary)
│   ├── USDInteropAdvancedEditing (proprietary)
│   ├── USDInteropAdvancedInspection (proprietary)
│   └── USDInteropAdvancedUtils (proprietary)
├── DeconstructedUSDPipeline
│   ├── USDInteropAdvancedCore (proprietary)
│   ├── USDInteropAdvancedWorkflows (proprietary)
│   └── USDInteropAdvancedAppleTools (proprietary)
├── SceneGraphClients
│   ├── USDInteropAdvancedCore (proprietary)
│   ├── USDInteropAdvancedUtils (proprietary)
│   └── USDInteropAdvancedInspection (proprietary)
├── InspectorFeature
│   ├── USDInteropAdvancedCore (proprietary)
│   ├── USDInteropAdvancedUtils (proprietary)
│   └── USDInteropAdvancedInspection (proprietary)
└── InspectorModels
    └── USDInteropAdvancedCore (proprietary)
```

### What Deconstructed Uses from USDTools

#### 1. Core Client (`USDInteropAdvancedCore`)
```swift
// The main entry point - USDAdvancedClient
let client = USDInteropAdvancedCore.USDAdvancedClient()
```

**Operations used:**
- `allMaterials(url:)` - List all materials in scene
- `materialBinding(url:path:)` - Get material binding
- `setMaterialBinding(url:primPath:materialPath:editTarget:)` - Set material binding
- `clearMaterialBinding(url:primPath:editTarget:)` - Clear material binding
- `materialBindingStrength(url:path:)` - Get binding strength
- `setMaterialBindingStrength(url:primPath:strength:editTarget:)` - Set strength
- `setDefaultPrim(url:primPath:)` - Set default prim
- `applySchema(url:primPath:schema:)` - Apply USD schema
- `createPrim(url:parentPath:name:typeName:)` - Create prims
- `existingPrimNames(url:parentPath:)` - List existing names
- `stageMetadata(url:)` - Get stage metadata
- `primAttributes(url:path:)` - Get prim attributes
- `primTransform(url:path:)` - Get transform
- `primReferences(url:path:)` - Get references
- `listVariantSets(url:scope:)` - List variant sets
- `applyVariantSelection(url:request:editTarget:persist:)` - Set variant
- `addReference(url:primPath:reference:editTarget:)` - Add reference
- `removeReference(url:primPath:reference:editTarget:)` - Remove reference
- `setPrimTransform(url:path:transform:)` - Set transform
- `setMetersPerUnit(url:value:)` - Set meters per unit
- `setUpAxis(url:axis:)` - Set up axis

#### 2. Pipeline Operations (`USDInteropAdvancedWorkflows`, `USDInteropAdvancedAppleTools`)
```swift
// Plugin conversion for USDZ import
convertPluginToUsdc(sourceURL:outputUSDC:resourcesURL:)
fixTexturePaths(in:resourcesDir:sourceDir:)
fixTextureWiring(in:)
```

#### 3. Data Types (mostly from `USDInterfaces` - already public)
```swift
USDPrimAttributes           // Prim inspection data
USDTransformData            // Transform data
USDStageMetadata            // Stage metadata
USDMaterialInfo             // Material information
USDMaterialBindingStrength  // Binding strength enum
USDVariantSetDescriptor     // Variant set info
USDVariantSelectionRequest  // Variant selection
USDReference                // Reference data
USDSchemaSpec               // Schema specification
```

---

## Categorization: What's Proprietary vs. Open-Sourceable

### Category 1: Read-Only Operations (Can be Open-Sourced)

These operations only **read** USD data and can be implemented using the public `OpenUSD` Swift package:

| Operation | Current Implementation | Open-Source Alternative |
|-----------|----------------------|------------------------|
| `sceneGraphJSON()` | C++ in USDInterop | Swift parser using OpenUSD |
| `exportUSDA()` | C++ in USDInterop | Swift using OpenUSD |
| `sceneBounds()` | C++ in USDInterop | Swift using OpenUSD |
| `primAttributes()` | USDAdvancedClient | Swift wrapper over OpenUSD |
| `primTransform()` | USDAdvancedClient | Swift wrapper over OpenUSD |
| `primReferences()` | USDAdvancedClient | Swift wrapper over OpenUSD |
| `materialBinding()` | USDAdvancedClient | Swift wrapper over OpenUSD |
| `allMaterials()` | USDAdvancedClient | Swift wrapper over OpenUSD |
| `stageMetadata()` | USDAdvancedClient | Swift wrapper over OpenUSD |
| `listVariantSets()` | USDAdvancedClient | Swift wrapper over OpenUSD |

### Category 2: Basic Editing Operations (Can be Open-Sourced with Limitations)

These **write** operations can have basic Swift/OpenUSD implementations:

| Operation | Complexity | Open-Source Implementation |
|-----------|-----------|---------------------------|
| `setPrimTransform()` | Low | Direct OpenUSD API |
| `setDefaultPrim()` | Low | Direct OpenUSD API |
| `setMetersPerUnit()` | Low | Direct OpenUSD API |
| `setUpAxis()` | Low | Direct OpenUSD API |
| `createPrim()` | Medium | Direct OpenUSD API |
| `setMaterialBinding()` | Medium | OpenUSD with proper SdfPath handling |
| `applyVariantSelection()` | Medium | OpenUSD variant API |
| `addReference()` / `removeReference()` | Medium | OpenUSD reference API |

### Category 3: Proprietary Value (Keep in USDTools)

These provide significant value to Preflight and should remain proprietary:

| Feature | Why Proprietary |
|---------|----------------|
| **Texture Conversion** (`USDInteropAdvancedAppleTools`) | Uses Apple's proprietary texture tools, format optimizations |
| **USDZ Packaging** | Complex resource bundling, validation, optimization |
| **Plugin Conversion** (`convertPluginToUsdc`) | Handles third-party plugin formats, path rewriting |
| **Advanced Scene Surgery** (`USDInteropAdvancedSurgery`) | Complex scene manipulation, optimization passes |
| **Workflow Automation** (`USDInteropAdvancedWorkflows`) | Preflight-specific pipelines, batch processing |
| **Stage Caching** (`USDInteropAdvancedStageCache`) | Performance optimizations for large scenes |
| **Transform Support** (`USDInteropAdvancedTransformSupport`) | Advanced coordinate system handling |
| **Texture Path Fixing** | Smart resource resolution, bundling logic |
| **Validation & Diagnostics** | Preflight-specific validation rules |

---

## Proposed Architecture: USDToolsLite

### Concept

Create a new package **`USDToolsLite`** that provides:
1. **Read-only operations** using public OpenUSD Swift bindings
2. **Basic editing operations** with limited functionality
3. **Stub implementations** for advanced features that throw descriptive errors
4. **Protocol-based design** so Deconstructed code doesn't change

### Module Structure

```
USDToolsLite (open source)
├── USDToolsLiteCore
│   ├── Read-only inspection APIs
│   ├── Basic editing APIs
│   └── Stub implementations for advanced features
├── USDToolsLiteInspection
│   ├── Scene graph reading
│   ├── Prim attribute inspection
│   └── Material discovery
└── USDToolsLiteEditing
    ├── Basic prim creation
    ├── Transform editing
    ├── Simple variant switching
    └── Reference management

USDTools (proprietary)
├── All USDToolsLite functionality (full implementations)
├── USDToolsAdvanced (texture conversion, USDZ, etc.)
├── USDToolsWorkflows (batch processing, pipelines)
└── USDToolsApple (Apple-specific integrations)
```

### Implementation Strategy

#### 1. Protocol Abstraction Layer

Define protocols in a shared module that both implementations conform to:

```swift
// In USDToolsLite (and USDTools)
public protocol USDSceneInspecting {
    func primAttributes(url: URL, path: String) -> USDPrimAttributes?
    func primTransform(url: URL, path: String) -> USDTransformData?
    func allMaterials(url: URL) -> [USDMaterialInfo]
    // ... etc
}

public protocol USDSceneEditing {
    func createPrim(url: URL, parentPath: String, name: String, typeName: String) throws -> String
    func setPrimTransform(url: URL, path: String, transform: USDTransformData) throws
    // ... etc
}

public protocol USDAdvancedOperations {
    func convertPluginToUsdc(sourceURL: URL, outputUSDC: URL, resourcesURL: URL) throws
    func fixTexturePaths(in usdcURL: URL, resourcesDir: URL, sourceDir: URL) throws
    // ... etc
}
```

#### 2. Conditional Dependency Resolution

Use Swift Package Manager features to swap implementations:

```swift
// Package.swift
let package = Package(
    name: "Deconstructed",
    dependencies: [
        // Public dependencies (always used)
        .package(url: "https://github.com/Reality2713/USDInterop", from: "0.1.4"),
        
        // Choose ONE of these (via environment or local override)
        // Option A: Open source (for third-party devs)
        .package(url: "https://github.com/Reality2713/USDToolsLite", from: "0.1.0"),
        
        // Option B: Proprietary (for Preflight team)
        .package(url: "https://github.com/Reality2713/USDTools", from: "0.3.0"),
    ]
)
```

#### 3. Compilation Conditions (Alternative)

Use compiler flags for conditional compilation:

```swift
#if canImport(USDTools)
import USDTools
public typealias USDClient = USDTools.USDAdvancedClient
#elseif canImport(USDToolsLite)
import USDToolsLite
public typealias USDClient = USDToolsLite.USDLiteClient
#else
#error("Either USDTools or USDToolsLite must be available")
#endif
```

### Feature Matrix

| Feature | USDToolsLite | USDTools (Full) | Notes |
|---------|-------------|-----------------|-------|
| **Read Scene Graph** | ✅ Full | ✅ Full | Both use OpenUSD |
| **Export USDA** | ✅ Full | ✅ Full | Both use OpenUSD |
| **Get Scene Bounds** | ✅ Full | ✅ Full | Both use OpenUSD |
| **Inspect Prim Attributes** | ✅ Full | ✅ Full | Swift wrapper |
| **Get Transform** | ✅ Full | ✅ Full | Swift wrapper |
| **List Materials** | ✅ Basic | ✅ Advanced | Lite shows basic info |
| **Material Binding (read)** | ✅ Full | ✅ Full | Swift wrapper |
| **Set Transform** | ✅ Full | ✅ Full | Direct OpenUSD |
| **Create Prims** | ✅ Basic types | ✅ All types | Lite: basic geometric types |
| **Set Material Binding** | ✅ Basic | ✅ Advanced | Lite: simple binding only |
| **Variant Switching** | ✅ Basic | ✅ Advanced | Lite: root layer only |
| **Reference Management** | ✅ Basic | ✅ Advanced | Lite: simple references |
| **Schema Application** | ❌ | ✅ | Lite: not implemented |
| **Texture Conversion** | ❌ | ✅ | Proprietary value |
| **USDZ Packaging** | ❌ | ✅ | Proprietary value |
| **Plugin Import** | ❌ | ✅ | Proprietary value |
| **Scene Validation** | ⚠️ Basic | ✅ Advanced | Lite: basic checks only |
| **Workflow Automation** | ❌ | ✅ | Proprietary value |
| **Batch Processing** | ❌ | ✅ | Proprietary value |

---

## Implementation Plan

### Phase 1: Extract Protocols (Week 1)

1. Define all protocols in a new `USDInterfaces` extension
2. Update Deconstructed to use protocols instead of concrete types
3. Create adapter layer in DeconstructedUSDInterop

### Phase 2: Create USDToolsLite (Weeks 2-3)

1. Create `USDToolsLite` repository
2. Implement read-only operations using OpenUSD
3. Implement basic editing operations
4. Add stub implementations that throw for unsupported features

### Phase 3: Refactor Deconstructed (Week 4)

1. Update Deconstructed to work with both implementations
2. Add compile-time or runtime feature detection
3. Create graceful degradation paths

### Phase 4: Documentation & Release (Week 5)

1. Document feature differences
2. Create contributor guidelines
3. Release USDToolsLite as open source

---

## Code Changes Required in Deconstructed

### Current Code (Tightly Coupled)

```swift
// DeconstructedUSDInterop.swift
import USDInteropAdvancedCore

public enum DeconstructedUSDInterop {
    private static let advancedClient = USDInteropAdvancedCore.USDAdvancedClient()
    
    public static func primAttributes(url: URL, primPath: String) -> USDPrimAttributes? {
        advancedClient.primAttributes(url: url, path: primPath)
    }
}
```

### Proposed Code (Protocol-Based)

```swift
// DeconstructedUSDInterop.swift
#if canImport(USDTools)
import USDTools
private let client: USDSceneInspecting & USDSceneEditing = USDTools.USDAdvancedClient()
#elseif canImport(USDToolsLite)
import USDToolsLite
private let client: USDSceneInspecting & USDSceneEditing = USDToolsLite.USDLiteClient()
#endif

public enum DeconstructedUSDInterop {
    public static func primAttributes(url: URL, primPath: String) -> USDPrimAttributes? {
        client.primAttributes(url: url, path: primPath)
    }
}
```

### Runtime Feature Detection

```swift
// For features that may not be available in Lite
public enum USDFeatureAvailability {
    case available
    case limited(functionality: String)
    case unavailable(reason: String)
}

public protocol USDFeatureDetecting {
    func availability(of feature: USDFeature) -> USDFeatureAvailability
}

// In UI, show warnings for unavailable features
if case .unavailable(let reason) = client.availability(of: .textureConversion) {
    showProFeatureBanner("Texture conversion requires USDTools Pro: \(reason)")
}
```

---

## Benefits

### For Third-Party Developers

1. **Can build and run Deconstructed** without access to proprietary code
2. **Can contribute** to UI, project management, scene graph features
3. **Clear understanding** of what's possible in open-source vs. proprietary

### For Preflight Team

1. **Protects proprietary value** in texture conversion, USDZ packaging, workflows
2. **Maintains competitive advantage** in professional tool offerings
3. **Community contributions** to open-source portions improve the product
4. **Clear upgrade path** from Lite to Pro for users who need advanced features

---

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Feature parity confusion | Clear documentation, runtime feature detection |
| Support burden | Community support for Lite, paid support for Pro |
| Code divergence | Shared protocols ensure API compatibility |
| Reverse engineering | Core value is in complex workflows, not basic operations |

---

## Appendix: Detailed API Audit

### Files Requiring Changes

| File | USDTools Imports | Changes Needed |
|------|-----------------|----------------|
| `DeconstructedUSDInterop.swift` | AdvancedCore, AdvancedEditing, AdvancedInspection | Protocol abstraction |
| `DeconstructedUSDPipeline.swift` | AdvancedCore, AdvancedWorkflows, AdvancedAppleTools | Feature detection, stub handling |
| `SceneGraphClient.swift` | AdvancedCore, AdvancedUtils, AdvancedInspection | Already uses DeconstructedUSDInterop |
| `InspectorFeature.swift` | AdvancedCore, AdvancedUtils, AdvancedInspection | Feature detection for UI |
| `InspectorModels.swift` | AdvancedCore | Type aliases only |

### Lines of Code Impact

- **DeconstructedUSDInterop.swift**: ~2000 LOC → Refactor to use protocols (~100 LOC change)
- **DeconstructedUSDPipeline.swift**: ~28 LOC → Add feature detection (~50 LOC)
- **InspectorFeature.swift**: ~2500 LOC → Add feature availability checks (~200 LOC)

---

## Conclusion

The proposed **USDToolsLite** approach allows Deconstructed to be fully functional for third-party developers while protecting the proprietary value of USDTools. The key insight is:

> **Basic USD reading and simple editing** can be done with public OpenUSD bindings. **Advanced workflows, texture optimization, and professional pipelines** are the real value that should remain proprietary.

By using protocol-based abstraction and clear feature boundaries, we can:
1. Enable community contributions to Deconstructed
2. Maintain Preflight's competitive advantage
3. Provide a clear upgrade path for users who need advanced features
4. Keep the codebase clean and maintainable

---

*Document Version: 1.0*
*Last Updated: 2026-03-21*
