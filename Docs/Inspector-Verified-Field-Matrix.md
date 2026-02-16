# Inspector Verified Field Matrix

Last updated: 2026-02-16
Source fixture set:
- `/Volumes/Plutonian/_Developer/Deconstructed/references/ComponentExploration/Sources/ComponentExploration/ComponentExploration.rkassets`

## Intent

Document only fields that are directly observed in authored USDA, not guessed from UI labels or schema names.

## Observed Component IDs With Authored Fields

Only these component IDs currently have authored parameter lines in the fixture set:

1. `RealityKit.Billboard`
2. `RealityKit.Collider`
3. `RealityKit.CustomDockingRegion`
4. `RealityKit.ImageBasedLight`
5. `RealityKit.Reverb`
6. `RealityKit.VirtualEnvironmentProbe`

All other components in the fixture set are present as component prims but currently only author `info:id` (no parameter lines yet).

## Verified Field Mapping (Observed)

### RealityKit.Billboard

1. Top-level field:
   - `float blendFactor = 0`

### RealityKit.Collider

1. Top-level fields:
   - `uint group = 1`
   - `uint mask = 4294967295`
   - `token type = "Default"`
2. Descendant fields (`Shape` child prim):
   - `float3 extent = (0.2, 0.2, 0.2)`
   - `token shapeType = "Box"`

### RealityKit.CustomDockingRegion

1. Descendant fields (`m_bounds` child prim):
   - `float3 max = (1.2, 0.5, 0)`
   - `float3 min = (-1.2, -0.5, -0)`

### RealityKit.ImageBasedLight

1. Top-level field:
   - `bool isGlobalIBL = 0`

### RealityKit.Reverb

1. Top-level field:
   - `token reverbPreset = "MediumRoomTreated"`

### RealityKit.VirtualEnvironmentProbe

1. Top-level field:
   - `token blendMode = "single"`

## What This Means For Implementation

1. Typed mappings should be considered authoritative only for fields above.
2. For remaining components, fallback raw editing is still useful but not schema-verified from fixtures.
3. To complete typed parity, we need controlled before/after USDA diffs for each component parameter changed in RCP.

## Next Research Pass Needed

For each high-priority component (Point Light, Spot Light, Directional Light, Opacity, Model Sorting, Ambient/Spatial/Channel audio, Physics Body, Physics Motion):

1. Create one scene with only that component.
2. Change one parameter at a time in RCP.
3. Save and diff USDA.
4. Record:
   - owner prim path (component root vs descendant struct)
   - USD type token
   - attribute name
   - literal format
   - any enum token mapping
