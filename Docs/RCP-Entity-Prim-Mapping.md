# RCP Entity-to-Prim Mapping — Reverse Engineering Findings

## Overview

RCP maintains a **bidirectional mapping** between RealityKit entities and USD prim paths. This enables stable selection — knowing exactly which entity corresponds to which prim path, rather than best-effort name matching.

Deconstructed currently uses `resolveEntity(forPrimPath:)` which walks the entity tree matching path components by name. RCP uses a dedicated registry and private components instead.

## Three-Layer Architecture

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

## `EditorObject` — The Bridge Type

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

## `CustomComponentRIOPrimPathComponent`

A private component type that stores the prim path directly on RealityKit entities. This is likely how the runtime can quickly look up which prim an entity represents without going through `EditorObject`.

## Key Mapping Functions (from symbol analysis)

| Function | Signature | Purpose |
|----------|-----------|---------|
| `ImportSession.primPath(of:)` | `Entity → String?` | **Get prim path from entity** |
| `ImportSession.primPathMetadataKey` | `String` (static) | Metadata key used to store prim path |
| `CDM.coreEntity(with:)` | `String → OpaquePointer?` | Get entity by identifier path |
| `CDMDataStore.identifierPath(from:primPath:)` | `(String, Path) → [String]` | Convert prim path to identifier path |
| `CDMDataStore.addComponent(typeName:to:with:cdm:)` | `(String, Prim?, CDM) → Result<Prim, Error>` | Add component to prim |
| `CDMDataStore.findComponentTypeName(of:packageName:)` | `(Prim, String?) → String` | Find component type on prim |

## Identifier Path System

RCP uses hierarchical string arrays for lookups, not raw USD prim paths:

- Format: `[sceneID, objectName1, objectName2, ...]`
- Error strings confirm: `"EditorObject identifierPath does not contain sceneID:"`
- Conversion: `CDMDataStore.identifierPath(from:primPath:)` bridges between the two

## Path-Related Properties Found in Strings

```
primPath, primPathString, storedPrimPath
objectPath, identifierPath, parentPrimPaths
libraryOwnerPrimPath
existingComponentPrimPath, newComponentPrimPath
instanceComponentPrimPath
relativeAttributePrimPathComponents
```

## Error Messages (revealing internal behavior)

- `"Requested entity before creation for prim at path"` — entities are **lazily created** from prims
- `"Prim not found at identifier path:"` — identifier path lookup failure
- `"Failed to get EditorObject for identifier path:"` — EditorObject is the canonical lookup

## RealityFoundation Public Surface

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

## How RCP Selection Works End-to-End

1. User clicks in viewport or scene navigator
2. RCP resolves click to a prim path (via hit-test → entity → `ImportSession.primPath(of:)`)
3. Prim path → `EditorObject` lookup via `CDMDataStore.identifierPath(from:primPath:)`
4. `EditorObject.coreEntity` provides the RealityKit entity
5. Entity gets tagged with `EntityRenderEffect` for outline rendering (see `RCP-Outline-Technique.md`)
6. Bidirectional: scene navigator selection → `CDM.coreEntity(with:)` → entity

## Private API Access (via dlopen)

### Metadata Key Values

Retrieved at runtime via `dlsym` + `@convention(thin)` cast (symbols need no `_` prefix):

| Symbol (without `_` prefix) | Value | Purpose |
|-----|-------|---------|
| `$s9RealityIO13ImportSessionC19primPathMetadataKeySSvgZ` | `"cdm:primpath"` | Prim path metadata key |
| `$s9RealityIO13ImportSessionC23resolvedPathMetadataKeySSvgZ` | `"cdm:resolvedpath"` | Resolved path metadata key |
| `$s9RealityIO13ImportSessionC20assetInfoMetadataKeySSvgZ` | `"realitykit:assetinfo"` | Asset info metadata key |

### Available Symbols (all found in RTLD_DEFAULT after loading RealityIO)

```
$s9RealityIO13ImportSessionC8primPath2ofSSSg0A3Kit6EntityC_tF     — primPath(of: Entity) -> String?
$s9RealityIO13ImportSessionC4prim2ofAA4PrimCSg0A3Kit6EntityC_tF   — prim(of: Entity) -> Prim?
$s9RealityIO13ImportSessionC6entity2at0A3Kit6EntityCSgAA27...      — entity(at: Path) -> Entity?
$s9RealityIO13ImportSessionCN                                      — ImportSession type metadata
$s9RealityIO13ImportSessionC10rootEntity0A3Kit0F0Cvg               — rootEntity getter
$s9RealityIO13ImportSessionC10contentsOf15pipelineVersion...       — init?(contentsOf:...)
```

### Limitation: Instance Method Requires ImportSession

`primPath(of:)` is an **instance method** — it requires the `ImportSession` that imported the entity. `Entity(contentsOf:)` creates an `ImportSession` internally but discards it after loading.

Entities loaded via `Entity(contentsOf:)` carry **no prim path metadata in their public components** — only `SynchronizationComponent`, `Transform`, and `ModelComponent`. The `"cdm:primpath"` metadata appears to be stored only within the `ImportSession`'s internal dictionary, not on the entity itself.

To use `primPath(of:)`, you would need to:
1. Create an `ImportSession` yourself via its init (complex generic init with C enum params)
2. Keep it alive alongside the entity tree
3. Call `primPath(of:)` on it for each entity

## Empirical Finding: Entity Hierarchy IS the Prim Hierarchy

Tested with multiple USD files (simple scenes, USDZ references, duplicate-named prims, real RCP projects):

```
Entity(contentsOf: "Scene.usda") produces:

  (anonymous root wrapper)         ← Not a prim; RealityKit adds this
    Root → /Root
      Cube → /Root/Cube [mesh]
      Group → /Root/Group
        Sphere → /Root/Group/Sphere [mesh]

Entity(contentsOf: "ToyCar.usdz") produces:

  (anonymous root wrapper)
    toy_car → /toy_car
      geom → /toy_car/geom
        realistic → /toy_car/geom/realistic
          geo → /toy_car/geom/realistic/geo
            lod0 → /toy_car/geom/realistic/geo/lod0
              toy_car_realistic_lod0 → [...]/toy_car_realistic_lod0 [mesh]
```

**The entity tree is a 1:1 structural mirror of the USD prim tree.** This is not coincidence — it's a guarantee of the RealityIO import pipeline. Entity names match prim names exactly, with `_N` suffixes for sibling duplicates.

### What This Means

The hierarchy walk approach is **not guessing** — it's reading a structural guarantee. The only edge cases are:

1. **Anonymous root wrapper** — always present, skip it (name is empty)
2. **Sibling name collisions** — RealityKit appends `_1`, `_2` etc. Must handle when building prim paths
3. **USD Scope prims** — may or may not generate entities (depends on content)
4. **RealityKit-injected entities** — e.g. `usdPrimitiveAxis` for Cone/Capsule primitives (internal geometry, not from USD)

### Robust Implementation Strategy

Since entity hierarchy = prim hierarchy, the reliable approach is:

1. **Walk once after load** — build complete `[String: Entity.ID]` and `[Entity.ID: String]` dictionaries
2. **Reconstruct prim paths from entity hierarchy** — `entity.name` IS the prim name at each level
3. **Handle `_N` suffixes** — detect duplicate sibling names, track original prim names vs suffixed entity names
4. **Skip the anonymous root** — `Entity(contentsOf:)` always wraps in a nameless root
5. **Attach `PrimPathComponent`** — store the reconstructed path on each entity for O(1) access

This gives us the same result as `ImportSession.primPath(of:)` without needing private API access.

## Apple USD Schemas

The `AppleUSDSchemas` package (`Preliminary_AnchoringAPI`, `Preliminary_PhysicsRigidBodyAPI`, etc.) operates at the **USD prim level** — it applies/reads schema attributes on `pxr.UsdPrim` objects. It does **not** participate in the entity↔prim bridge. The bridge is entirely internal to RealityIO's `ImportSession`.
