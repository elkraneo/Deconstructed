# Inspector Verified Field Matrix

Last updated: 2026-02-19
Source fixture set:
- `/Volumes/Plutonian/_Developer/Deconstructed/references/ComponentExploration/Sources/ComponentExploration/ComponentExploration.rkassets`
- `/Volumes/Plutonian/_Developer/Deconstructed/references/ComponentFieldExploration/Sources/ComponentFieldExploration/ComponentFieldExploration.rkassets`

## Intent

Document only fields that are directly observed in authored USDA, not guessed from UI labels or schema names.

Related deep-dive:

- `Docs/Audio-Component-Library-Relationship.md`

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
12. `RealityKit.SpatialAudio` (from `ComponentFieldExploration` diffs)
13. `RealityKit.ChannelAudio` (from `ComponentFieldExploration` diffs)
14. `RealityKit.AudioLibrary` (from `ComponentFieldExploration` diffs)
15. `RealityKit.AnimationLibrary` (from `ComponentFieldExploration` diffs)
16. `RealityKit.CharacterController` (from `ComponentFieldExploration` diffs)
17. `RCP.BehaviorsContainer` (from `ComponentFieldExploration` diffs)
18. `RealityKit.InputTarget` (from `ComponentFieldExploration` diffs)

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
2. Preview video fixture (`PreviewVideo.usda`) authors on component prim metadata:
   - `customData.previewVideo` as `asset` path
3. In observed RCP fixture, preview video is referenced externally (path escaping out of project); no auto-copy into `.rkassets` was authored.

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

### RealityKit.SpatialAudio

1. Top-level fields:
   - `float gain = ...`
   - `float directLevel = ...`
   - `float reverbLevel = ...`
   - `float rolloffFactor = ...`
   - `float directivityFocus = ...`
2. In current fixtures, no additional authored field for Preview/Resource is present.

### RealityKit.ChannelAudio

1. Top-level field:
   - `float gain = ...`
2. In current fixtures, no additional authored field for Preview/Resource is present.

### RealityKit.AudioLibrary

1. Top-level component:
   - `uniform token info:id = "RealityKit.AudioLibrary"`
2. Descendant `def RealityKitDict "resources"` fields:
   - `string[] keys = [...]`
   - `rel values = </Root/...>`
3. Audio file prims are authored separately (outside component):
   - `def RealityKitAudioFile "<name>"`
   - `uniform asset file = @...@`
   - `uniform bool shouldLoop = 0|1`

### RealityKit.AnimationLibrary

1. Top-level component:
   - `uniform token info:id = "RealityKit.AnimationLibrary"`
2. Animation entries are authored as child prims under the component:
   - `def RealityKitAnimationFile "<sanitized_prim_name>"`
   - `uniform asset file = @../<clip>.usdc@` (or `usda`/`usdz`)
   - `uniform string name = "<display name>"`
3. Add/remove behavior is represented by creating/deleting `RealityKitAnimationFile` child prims.
4. In current fixtures, the Frames/Seconds toggle does not author scene data (no USDA delta vs base).
5. Deconstructed inspector status:
   - Component-specific module is implemented (list + add/remove).
   - Add imports `usda`/`usdc`/`usdz` clips into `.rkassets`.
   - Remove deletes the selected `RealityKitAnimationFile` child prim.

### RealityKit.CharacterController

1. Top-level component:
   - `uniform token info:id = "RealityKit.CharacterController"`
2. Descendant struct path:
   - `m_controllerDesc` / `collisionFilter`
3. Observed authored fields in fixtures:
   - `float3 extents` (height/radius packed into vector channels)
   - `float skinWidth`
   - `float slopeLimit` (authored in radians)
   - `float stepLimit`
   - `uint group` (collision filter)
   - `uint mask` (collision filter)
4. Up Vector fixture observation:
   - Up Vector edits changed prim transform (`xformOp:orient` + `rotationEulerHint`) and did not author a dedicated CharacterController up-vector field in observed USDA.

### RCP.BehaviorsContainer (Behaviors)

1. Container component on entity:
   - `def RealityKitComponent "RCP_BehaviorsContainer"`
   - `uniform token info:id = "RCP.BehaviorsContainer"`
   - `rel behaviors = ...`
2. Each behavior is authored as a graph root:
   - `def Preliminary_Behavior "<BehaviorName>"`
   - `rel triggers = ...`
   - `rel actions = ...`
3. Trigger/action nodes are nested graph nodes:
   - `def Preliminary_Trigger "Trigger"` with `token info:id = "TapGesture"|"Collide"|"Notification"|"SceneTransition"`
   - `def Preliminary_Action "Action"` with `token info:id = "PlayTimeline"` and loop/count/type attributes
4. Trigger-specific fields observed:
   - `rel colliders = </Root/...>` for collision trigger selection
   - `string identifier = "..."` for notification trigger
5. Stacked behaviors serialize as an ordered `rel behaviors` list.
6. `StackedReversed.usda` confirms behavior order is authored and changes when behavior order changes.
7. Practical implication: Behaviors are graph-authored, relation-heavy, and timeline-dependent (not scalar ECS fields).

### RealityKit.InputTarget

1. Top-level component:
   - `uniform token info:id = "RealityKit.InputTarget"`
2. Observed authored fields:
   - `bool enabled = 0|1`
   - `bool allowsDirectInput = 0|1`
   - `bool allowsIndirectInput = 0|1`
3. `Allowed Input = All` fixture (`AllowedInput/All.usda`) authored no delta vs base.
4. `Allowed Input = Direct` fixture authored:
   - `allowsDirectInput = 1`
   - `allowsIndirectInput = 0`
5. `Allowed Input = Indirect` fixture authored:
   - `allowsDirectInput = 0`
   - `allowsIndirectInput = 1`

### Ambient/Spatial/Channel Audio + Audio Library coupling

1. In current fixtures, selecting an Ambient Audio Preview resource does not author a direct field on `RealityKit.AmbientAudio`.
2. In current fixtures, selecting a Spatial Audio Preview resource does not author a direct field on `RealityKit.SpatialAudio`.
3. In current fixtures, selecting a Channel Audio Preview resource does not author a direct field on `RealityKit.ChannelAudio`.
4. Persisted resource data appears to live in `RealityKit.AudioLibrary` + `RealityKitAudioFile` prims.

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
