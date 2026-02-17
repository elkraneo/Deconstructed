# Inspector Verified Field Matrix

Last updated: 2026-02-17
Source fixture set:
- `/Volumes/Plutonian/_Developer/Deconstructed/references/ComponentExploration/Sources/ComponentExploration/ComponentExploration.rkassets`
- `/Volumes/Plutonian/_Developer/Deconstructed/references/ComponentFieldExploration/Sources/ComponentFieldExploration/ComponentFieldExploration.rkassets`

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
7. `RealityKit.SpotLight` (from `ComponentFieldExploration` diffs)
8. `RealityKit.PointLight` (from `ComponentFieldExploration` diffs)
9. `RealityKit.DirectionalLight` (from `ComponentFieldExploration` diffs)
10. `RealityKit.HierarchicalFade` (from `ComponentFieldExploration` diffs)
11. `RealityKit.AmbientAudio` (from `ComponentFieldExploration` diffs)

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

### RealityKit.PointLight

1. Top-level fields:
   - `float3 color = (...)`
   - `float intensity = ...`
   - `float attenuationRadius = ...`
   - `float attenuationFalloffExponent = ...`

### RealityKit.SpotLight

1. Top-level fields:
   - `float3 color = (...)`
   - `float intensity = ...`
   - `float innerAngle = ...`
   - `float outerAngle = ...`
   - `float attenuationRadius = ...`
   - `float attenuationFalloffExponent = ...`
2. Descendant `Shadow` struct fields:
   - `bool isEnabled = 1|0`
   - `float depthBias = ...`
   - `token cullMode = "Back"|"Front"` (not authored for `Default`/`None` in current fixtures)
   - `token zNear = "Fixed"` (absent for `Automatic`)
   - `token zFar = "Fixed"` (absent for `Automatic`)

### RealityKit.DirectionalLight

1. Top-level fields:
   - `float3 color = (...)`
   - `float intensity = ...`
2. Descendant `Shadow` struct fields:
   - `bool isEnabled = 1`
   - `float depthBias = ...`
   - `token cullMode = "Back"|"Front"|"None"` (not authored for `Default` in current fixtures)
   - `token projectionType = "Fixed"` (not authored in base/default)
   - `float orthographicScale = ...` (authored together with `projectionType = "Fixed"` in current fixtures)
   - `float2 zBounds = (...)` (authored together with `projectionType = "Fixed"` in current fixtures)

### RealityKit.HierarchicalFade (Opacity)

1. Top-level field:
   - `float opacity = ...`

### RealityKit.AmbientAudio

1. Top-level field:
   - `float gain = ...`
2. In current fixtures, no additional authored field for Preview/Resource is present.

### RealityKit.MeshSorting (Model Sorting)

1. Top-level component fields:
   - `rel group = </Root/Model_Sorting_Group>`
   - `int priorityInGroup = ...`
2. Group prim is authored separately:
   - `def RealityKitMeshSortingGroup "Model_Sorting_Group"`
3. Group prim field:
   - `token depthPass = "None"|"prePass"|"postPass"`

## What This Means For Implementation

1. Typed mappings should be considered authoritative only for fields above.
2. For remaining components, fallback raw editing is still useful but not schema-verified from fixtures.
3. To complete typed parity, we need controlled before/after USDA diffs for each component parameter changed in RCP.

## Next Research Pass Needed

For each high-priority component (Ambient/Spatial/Channel audio, Physics Body, Physics Motion):

1. Create one scene with only that component.
2. Change one parameter at a time in RCP.
3. Save and diff USDA.
4. Record:
   - owner prim path (component root vs descendant struct)
   - USD type token
   - attribute name
   - literal format
   - any enum token mapping
