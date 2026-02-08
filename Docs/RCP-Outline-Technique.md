# RCP Selection Outline Technique — Reverse Engineering Findings

## Overview

Reality Composer Pro implements selection outlines using a **2-pass mask + edge detection** technique via RealityKit's **private render graph system**. This is NOT achievable with public `PostProcessEffect` alone.

## Architecture

```
Pass 1: Outline Mask Pass
  ┌──────────────────────────┐
  │ vsOutlineMask (vertex)   │  Transforms selected entity meshes to clip space
  │ fsOutlineMask (fragment) │  Writes outlineChannel value to mask texture
  └──────────┬───────────────┘
             │ maskTexture (offscreen render target)
             ▼
Pass 2: Outline Edge Pass (fullscreen quad)
  ┌──────────────────────────┐
  │ vsOutlineEdge (vertex)   │  Fullscreen quad
  │ fsOutlineEdge (fragment) │  Edge-detects mask → composites colored outline
  └──────────────────────────┘
```

## Source Evidence (from `RealityToolsFoundation.framework`)

### Build paths leaked in binary strings:

```
RETools/Source/RealityToolsFoundation/Renderer/Visual Cue System/Visual Cues/SelectionVisualCue.swift
RETools/Source/RealityToolsFoundation/Renderer/Gizmos/DropTargetGizmo.swift
RETools/Source/RealityToolsFoundation/Renderer/Gizmos/WorkspaceGridGizmo.swift
```

### Render graph resources (private `.rerendergraph` / `.rematerial` format):

```
framework:com.apple.RealityToolsFoundation/selection.rerendergraphemitter
framework:com.apple.RealityToolsFoundation/outlineEdge.rematerial
framework:com.apple.RealityToolsFoundation/camera.rerendergraph
framework:com.apple.RealityToolsFoundation/texturePassthrough.rerendergraph
framework:com.apple.RealityToolsFoundation/assetViewForSelection.rerendergraphemitter
```

### Metal shader functions (from `default.metallib` in RealityToolsFoundation):

| Function | Purpose |
|----------|---------|
| `vsOutlineMask` | Vertex shader: transforms entity mesh to clip space, passes `outlineChannel` |
| `fsOutlineMask` | Fragment shader: writes channel value to mask render target |
| `vsOutlineEdge` | Vertex shader: fullscreen quad |
| `fsOutlineEdge` | Fragment shader: samples `maskTexture`, edge-detects, composites outline |

### Shader uniforms (from metallib metadata):

**Mask pass (`vsOutlineMask` / `fsOutlineMask`):**
- `objectToCrWorld` — model-to-world matrix (float4x4)
- `crWorldToProjArray` — world-to-projection matrix (float4x4)
- `outlineChannel` — which outline channel to write (float, encoded as enum)

**Edge pass (`fsOutlineEdge`):**
- `selectionOutlineColor` — orange for selection (half4)
- `manipulatorOutlineColor` — color for manipulator outlines (half4)
- `behaviorTargetOutlineColor` — color for behavior target outlines (half4)
- `outlineThicknessPx` — outline width in **pixels** (float) — this is why it's constant screen-space width
- `maskTexture` — the mask render target (texture2d<half, sample>)

## Outline Channel System

RCP supports **three independent outline channels** via `RendererOutlineEffectChannel` enum:

| Channel | Purpose | Color property |
|---------|---------|---------------|
| `SelectionOutlineMask` | Selected entities | `selectionOutlineColor` (orange) |
| `ManipulatorOutlineMask` | Active gizmo/manipulator | `manipulatorOutlineColor` |
| `BehaviorTargetOutlineMask` | Behavior target entities | `behaviorTargetOutlineColor` |

Additional variants:
- `SubAFSelectionOutlineMask` / `SubAFSelectionOutlineMaskNode` — sub-asset-file selection
- `ForceClearOutlineMasks` — clears all outline masks

## Key Types (from demangled symbols)

### `RendererBase` (the core renderer)
```swift
class RendererBase {
    var selectionOutlineColor: SIMD4<Float>   // RGBA outline color
    var caMetalLayer: CAMetalLayer?           // Metal rendering surface
    var ecsManager: OpaquePointer             // ECS engine handle
    var assetManager: OpaquePointer           // Asset loading
    var visualCueManager: VisualCueManager    // Manages all visual cues
    var renderContext: RenderContext           // Current render state
    func stepEngine()                         // Advance simulation
}
```

### `EntityRenderEffect` — how outlines are applied to entities
```swift
struct EntityRenderEffect { ... }

// Applied via extension on OpaquePointer (entity handle):
extension OpaquePointer {
    func set(renderEffects: [EntityRenderEffect],
             includeDescendants: Bool,
             renderManager: OpaquePointer?)
}
```

This is the critical API: RCP calls `entity.set(renderEffects:includeDescendants:renderManager:)` to tag an entity for outline rendering. The render graph then picks up these tags and renders the entity to the mask texture.

### `SelectionVisualCue`
```swift
class SelectionVisualCue {
    var ringEntity: OpaquePointer?            // Bounding ring entity
    var selectable: Selectable?               // The selected object
    var sizePolicy: SizePolicy?               // How to size the outline
    var canInteract: Bool
    var handleSpace: CoordinateSpace
    var renderEffectsUsedByCue: [EntityRenderEffect]  // Outline mask effects

    func buildVisualCue(params: Params)
    func destroyVisualCue()
}
```

### `VisualCueManager`
```swift
class VisualCueManager {
    func isOutlineEffectRegistered(channel: RendererOutlineEffectChannel) -> Bool
    var visualCuesWithRenderEffects: [VisualCueProtocol]
}
```

## Why This Can't Be Done With Public APIs

1. **No object-ID buffer**: `PostProcessEffect` provides color + depth textures only
2. **No custom render targets**: Can't render specific entities to an offscreen mask texture
3. **No render graph injection**: The `.rerendergraph` / `.rerendergraphemitter` system is private
4. **No per-entity render effects**: `EntityRenderEffect` and `set(renderEffects:)` are private
5. **No pixel-space outline width**: Public CustomMaterial geometry modifiers work in model space

## Potential Private API Access

### Option A: `dlopen` + `dlsym` RealityToolsFoundation
The framework lives in the RCP app bundle. Could potentially:
1. `dlopen` the framework at runtime
2. Find `SelectionVisualCue` and `RendererBase` class metadata
3. Instantiate and configure via Swift metadata hacking

**Risk**: Very fragile, breaks across Xcode versions, requires matching ABI.

### Option B: Reproduce the technique
Since we know the exact Metal shader technique:
1. Write our own `vsOutlineMask`/`fsOutlineMask` + `vsOutlineEdge`/`fsOutlineEdge`
2. Use `PostProcessEffect` to run the edge pass
3. For the mask pass, use `CustomMaterial` with a surface shader that encodes an identifier into a channel (e.g., emissive), then extract that in PostProcessEffect

**Challenge**: The mask won't be clean — other emissive surfaces would contaminate it.

### Option C: Dual-RealityView mask approach
1. Maintain a second (hidden) RealityView with only selected entities + flat color material
2. Snapshot it to a texture each frame
3. Use that texture as the mask in PostProcessEffect on the main view

**Challenge**: Performance cost of two RealityView instances, synchronization.

### Option D: CustomMaterial geometry modifier (current best public approach)
Per-vertex normal extrusion + front-face culling. Not pixel-perfect but functional.

## Entity-to-USD-Prim Mapping (Private)

RCP maintains a **bidirectional mapping** between RealityKit entities and USD prim paths. This is critical for stable selection — knowing exactly which entity corresponds to which prim path, rather than best-effort name matching.

### Three-Layer Architecture

```
USD Layer (RealityIO)
  │  RealityIO.Prim, SceneDescriptionFoundations.Path, Stage
  │
  ▼
Bridge Layer (RealityToolsFoundation)
  │  EditorObject — central registry holding both sides
  │
  ▼
Runtime Layer (RealityKit/RealityFoundation)
     Entity with localId: UInt64, components
```

### `EditorObject` — The Bridge Type

```swift
struct EditorObject {
    var prim: RealityIO.Prim?              // USD prim reference
    var identifierPath: [String]           // Hierarchical path [sceneID, name1, name2, ...]
    var objectPath: String                 // String path representation
    var coreEntity: OpaquePointer?         // Direct RealityKit entity pointer
    var coreEntityID: UInt64?              // Entity ID for fast lookups
}
```

`EditorObject` is the **primary abstraction** that connects the USD world to the RealityKit world. Every selectable object in RCP has an `EditorObject`.

### `CustomComponentRIOPrimPathComponent`

A private component type that stores the prim path directly on RealityKit entities. This is likely how the runtime can quickly look up which prim an entity represents without going through `EditorObject`.

### Key Mapping Functions (from symbol analysis)

| Function | Signature | Purpose |
|----------|-----------|---------|
| `ImportSession.primPath(of:)` | `Entity → String?` | **Get prim path from entity** |
| `ImportSession.primPathMetadataKey` | `String` (static) | Metadata key used to store prim path |
| `CDM.coreEntity(with:)` | `String → OpaquePointer?` | Get entity by identifier path |
| `CDMDataStore.identifierPath(from:primPath:)` | `(String, Path) → [String]` | Convert prim path to identifier path |
| `CDMDataStore.addComponent(typeName:to:with:cdm:)` | `(String, Prim?, CDM) → Result<Prim, Error>` | Add component to prim |
| `CDMDataStore.findComponentTypeName(of:packageName:)` | `(Prim, String?) → String` | Find component type on prim |

### Identifier Path System

RCP uses hierarchical string arrays for lookups, not raw USD prim paths:

- Format: `[sceneID, objectName1, objectName2, ...]`
- Error strings confirm: `"EditorObject identifierPath does not contain sceneID:"`
- Conversion: `CDMDataStore.identifierPath(from:primPath:)` bridges between the two

### Path-Related Properties Found in Strings

```
primPath, primPathString, storedPrimPath
objectPath, identifierPath, parentPrimPaths
libraryOwnerPrimPath
existingComponentPrimPath, newComponentPrimPath
instanceComponentPrimPath
relativeAttributePrimPathComponents
```

### Error Messages (revealing internal behavior)

- `"Requested entity before creation for prim at path"` — entities are **lazily created** from prims
- `"Prim not found at identifier path:"` — identifier path lookup failure
- `"Failed to get EditorObject for identifier path:"` — EditorObject is the canonical lookup

### RealityFoundation Public Surface

RealityFoundation exposes some related types publicly:

```swift
// USD encoding (public but limited)
protocol __USDEncodablePublic {
    func encode(to encoder: __USDEncoder, at parentPath: __USKObjectPathWrapper) throws -> __USKNodeWrapper
}

// Entity path navigation (public)
struct EntityPath {
    func entity(_ name: String) -> BindTarget.EntityPath
}

extension Entity {
    subscript(entityPath: BindTarget.EntityPath) -> Entity?
}
```

### Implications for Deconstructed

The current approach in `ViewportView.resolveEntity(forPrimPath:)` uses best-effort name matching to walk the entity tree. RCP instead:

1. Maintains `EditorObject` registry with bidirectional entity↔prim references
2. Stores prim paths on entities via `CustomComponentRIOPrimPathComponent`
3. Uses `ImportSession.primPath(of:)` to go from entity → prim path
4. Uses `CDM.coreEntity(with:)` to go from identifier path → entity

For a more robust implementation, Deconstructed could:
1. Create a similar registry populated during USD scene loading
2. Use a custom `PrimPathComponent` to store the prim path on each entity
3. Build a `[String: Entity.ID]` dictionary (primPath → entityID) at load time
4. Use `ImportSession.primPathMetadataKey` if accessible, or walk the entity tree once after load to build the mapping

## Conclusion

RCP's outline quality comes from a **multi-pass render graph technique** using private RealityKit APIs that are not exposed to third-party developers. The `EntityRenderEffect` system and `.rerendergraph` format are the key private components.

RCP's selection stability comes from `EditorObject` — a bridge type maintaining bidirectional entity↔prim references, augmented by `CustomComponentRIOPrimPathComponent` on entities and `ImportSession.primPath(of:)` for runtime lookups.

For a research/non-commercial project, the most promising paths are:
- **Outlines**: Reproduce the mask+edge technique using `PostProcessEffect` with `CustomMaterial` to encode selection state
- **Selection mapping**: Build an `EditorObject`-like registry during scene load, or explore accessing `ImportSession.primPath(of:)` via private API
