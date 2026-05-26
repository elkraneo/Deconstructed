# ImportSession Prim→Entity Mapping Algorithm — Specification

## Source

Derived from:
1. Binary analysis of `RealityIO.framework` via `xcrun dyld_info -exports` (all symbol names, prim class types, schema protocol conformances)
2. Empirical testing of `Entity(contentsOf:)` with controlled USD files on macOS 26 (Tahoe)
3. Cross-reference with `StageView/RealityKitProvider.swift` (prior art)

No private API is used. This spec describes what RealityIO does so we can replicate it.

---

## Primary Rule: Scope is Transparent

**UsdGeomScope prims produce NO entity.** Their children are hoisted to the scope's nearest non-Scope ancestor in the entity hierarchy. This applies recursively — nested Scopes all collapse to the same nearest ancestor.

```
USD:                                Entity tree:
Root                                Root
  OuterScope (Scope) ──┐              DeepCube   ← collapsed through both scopes
    InnerScope (Scope)  ├─ invisible  ScopeChild ← same
      DeepCube (Cube)  ─┘
    ScopeChild (Sphere)
```

This is the **primary source of entity path ≠ USD path divergence**.

---

## Prim Type → Entity Generation Rules

### Creates entity (confirmed empirically + via binary analysis of RealityIO)

| USD prim type | RealityIO class | Entity behavior |
|---|---|---|
| `Xform` | `XformPrim` | Container entity, no components |
| `Mesh` | `MeshPrim` | Entity with `ModelComponent` |
| `Sphere` | `SpherePrim` | Entity + RealityKit-injected `usdPrimitiveAxis` child |
| `Cube` | `CubePrim` | Entity with primitive geometry |
| `Cylinder` | `CylinderPrim` | Entity + injected `usdPrimitiveAxis` child |
| `Cone` | `ConePrim` | Entity + injected `usdPrimitiveAxis` child |
| `Capsule` | `CapsulePrim` | Entity + injected `usdPrimitiveAxis` child |
| `SkelRoot` | (no dedicated prim class) | Entity created |
| `Skeleton` | (no dedicated prim class) | Entity created |
| `Preliminary_Text` (Apple schema) | `PreliminaryTextPrim` | Entity created |

### Does NOT create entity (confirmed)

| USD prim type | Reason |
|---|---|
| `Scope` | Transparent — completely absent from entity hierarchy |
| `Material` | No entity. Also absent even when nested inside Scope |
| `Shader` | No entity |
| `GeomSubset` | Sub-mesh face set, no standalone entity |
| `Camera` | Not loaded as scene entity |
| `UsdLux` lights | Not loaded as scene entity |
| Audio prims | No entity in RK hierarchy (tracked by `AudioConstantsO` in RealityIO) |
| Timeline/Action prims | No entity (behavior data) |
| `BlendShape` | Part of mesh data, not a separate entity |

---

## Entity Naming Rules

1. `entity.name == prim.GetName()` — exact match for all entity-producing prims
2. **Anonymous root wrapper** — `Entity(contentsOf:)` always wraps in a single nameless root entity. Its `name` is empty. This is NOT a prim; skip it.
3. **RealityKit-injected names** — `usdPrimitiveAxis` is injected as a child of Sphere/Cylinder/Cone/Capsule prims. These have no USD prim counterpart. Known set: `{ "usdPrimitiveAxis" }`.
4. **Sibling `_N` suffix** — RealityKit appends `_1`, `_2`, etc. for sibling name collisions. Valid USD does not allow duplicate sibling prim names, so this primarily happens with injected entities or edge cases from variant composition.

---

## Entity Path vs. USD Path

Due to Scope collapsing, the reconstructed path from the entity tree may differ from the actual USD prim path.

| Entity hierarchy path | Actual USD path |
|---|---|
| `/Root/DeepCube` | `/Root/OuterScope/InnerScope/DeepCube` |
| `/Root/ScopeChild` | `/Root/OuterScope/ScopeChild` |
| `/Root/Cube` | `/Root/Cube` (no scope, matches exactly) |

**Implication for selection**: When Hydra (SceneGraph/USD side) provides a full USD path including Scope segments, and the entity mapping only knows the collapsed entity path, an exact lookup will fail. The 5-level fallback in `selectionEntity(for:)` handles this:
1. Exact match
2. Nearest ancestor match
3. Dropped-leading-segment candidates (removes known prefix segments)
4. Nearest descendant match
5. Best suffix match (catches leaf-name hits through Scope collapse)

---

## Authoritative Mapping: Two Approaches

### Approach A — Entity-Tree Walk (current StageView implementation)

Walk `Entity(contentsOf:)` result. Reconstruct paths from entity hierarchy. Fast, no USD dependency at lookup time. **Path produced is entity-path, not USD-path.** Requires fallback for Scope-collapsed lookups.

```swift
// Entity path (reconstructed): "/Root/DeepCube"
// USD path (actual):            "/Root/OuterScope/InnerScope/DeepCube"
```

Use when: you don't have SwiftUSD, or you control both the entity selection and the USD lookup so paths can be kept in sync.

### Approach B — Stage-Driven Walk (proposed PrimEntitySession)

Walk `pxr.UsdStage`. For each prim, determine if it generates an entity. Build a "virtual entity path" that skips Scope segments. Then correlate with entity tree.

```
Stage walk:
  /Root              → entity path: /Root
  /Root/OuterScope   → Scope, skip — entity path stays at parent: /Root
  /Root/OuterScope/InnerScope → Scope, skip — entity path: /Root
  /Root/OuterScope/InnerScope/DeepCube → entity path: /Root/DeepCube → find entity
```

The resulting mapping stores both:
- `entityIDToUSDPath["DeepCube-entity-id"] = "/Root/OuterScope/InnerScope/DeepCube"` ← true USD path
- `entityIDToEntityPath["DeepCube-entity-id"] = "/Root/DeepCube"` ← entity hierarchy path

Use when: you have SwiftUSD loaded and need accurate USD path round-trips.

---

## RealityIO Private API Metadata Keys (via dlsym, confirmed)

| Symbol | Value |
|---|---|
| `ImportSession.primPathMetadataKey` | `"cdm:primpath"` |
| `ImportSession.resolvedPathMetadataKey` | `"cdm:resolvedpath"` |
| `ImportSession.assetInfoMetadataKey` | `"realitykit:assetinfo"` |

These are stored internally in `ImportSession`'s dictionary. They are NOT accessible on entities loaded via `Entity(contentsOf:)` (which discards the ImportSession after loading).

---

## RealityIO Prim Class Inventory (from `xcrun dyld_info -exports`)

Confirmed classes in `RealityIO.framework`:
- `XformPrim` (UsdGeomXform)
- `MeshPrim` (UsdGeomMesh)
- `SpherePrim` (UsdGeomSphere)
- `CubePrim` (UsdGeomCube)
- `CylinderPrim` (UsdGeomCylinder)
- `ConePrim` (UsdGeomCone)
- `CapsulePrim` (UsdGeomCapsule)
- `PreliminaryTextPrim` (Apple Preliminary_Text schema)
- `StaticTypePrim<T>` — generic typed prim wrapper (protocol conformance machinery)
- `TypeNamePrimDirtyState` — editor dirty-state tracking (not entity creation)

Notable absence: no `ScopePrim`, no `CameraPrim`, no `LightPrim`, no `MaterialPrim` — confirms these don't go through the entity-creation path.

---

## Implementation: Standalone `buildPrimPathMapping`

See `Sources/PrimEntityMapping/PrimPathMapping.swift` for the public implementation.

The function signature:

```swift
/// Build bidirectional entity↔prim-path mapping by walking the entity hierarchy.
///
/// Paths produced are "entity paths" — they match the entity hierarchy structure.
/// Due to UsdGeomScope transparency, entity paths may differ from USD prim paths
/// when Scope prims exist in the USD file (see ImportSession-Algorithm-Spec.md).
///
/// - Parameter root: The root entity returned by `Entity(contentsOf:)`.
/// - Returns: A `PrimPathMapping` with bidirectional lookup dictionaries.
public func buildPrimPathMapping(root: Entity) -> PrimPathMapping
```

---

## Open Questions

- Does `UsdGeomPoints` / `UsdGeomBasisCurves` produce entities? (Not tested)
- Does `UsdGeomPointInstancer` produce entities per-instance or one entity for the instancer? (Not tested)
- What exactly triggers the `_N` suffix for a Sphere's `usdPrimitiveAxis` child vs. user-defined prim also named `usdPrimitiveAxis`?
- `RealityFoundation.__RKEntityComponent` / `CustomComponentRIOPrimPathComponent` — do loaded entities ever carry accessible metadata?
