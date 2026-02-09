# RCP Outline Rendering — Reverse Engineering Findings

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

## Reproduction Options

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

### Option D: CustomMaterial geometry modifier (current implementation)
Per-vertex normal extrusion + front-face culling. Not pixel-perfect but functional.
See `Packages/DeconstructedLibrary/Sources/SelectionOutline/`.
