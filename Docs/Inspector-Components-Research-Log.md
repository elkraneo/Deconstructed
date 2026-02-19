# Inspector Components Research Log

Last updated: 2026-02-16

## Goal

Document what we have verified about Reality Composer Pro (RCP) component authoring and what has already been implemented in Deconstructed for inspector/component parity.

This file is intended as source material for upcoming article drafts.

## Source Projects Used

Primary reference project:

- `/Volumes/Plutonian/_Developer/Deconstructed/references/ComponentExploration`

Schema source references:

- `/Users/elkraneo/Downloads/SchemaDefinitionsForThirdPartyDCCs`
- `/Volumes/Plutonian/_Developer/AppleUSDSchemas`

## RCP Component Catalog (from UI + fixtures)

### General

1. Accessibility
2. Anchoring
3. Animation Library
4. Behaviors
5. Billboard
6. Character Controller
7. Docking Region
8. Input Target
9. Model Sorting
10. Opacity
11. Particle Emitter
12. Scene Understanding

### Audio

1. Audio Library
2. Spatial Audio
3. Ambient Audio
4. Channel Audio
5. Audio Mix Groups
6. Reverb

### Lighting

1. Directional Light
2. Environment Lighting Configuration
3. Grounding Shadow
4. Image Based Light
5. Image Based Light Receiver
6. Point Light
7. Spot Light
8. Virtual Environment Probe

### Physics

1. Collision
2. Physics Body
3. Physics Motion

Notes:

1. `New Component` appears as an action, not a standard built-in component entry.
2. Some components can be invalid for current selection context (RCP shows disabled state + tooltip).

## Verified USD Authoring Patterns

## Built-in components

Built-ins are authored as child prims of type `RealityKitComponent` with `uniform token info:id`.

Pattern:

```usda
def RealityKitComponent "<PrimName>"
{
    uniform token info:id = "<Identifier>"
}
```

Example:

- `Accessibility.usda` uses `RealityKitComponent "Accessibility"` + `info:id = "RealityKit.Accessibility"`.

## Custom components (`New Component`)

RCP authors custom components with a different prim type:

```usda
def RealityKitCustomComponent "<Module>_<TypeName>"
{
    uniform token info:id = "<Module>.<TypeName>"
}
```

Verified in:

- `/Volumes/Plutonian/_Developer/Deconstructed/references/ComponentExploration/Sources/ComponentExploration/ComponentExploration.rkassets/New Component.usda`

RCP also generates Swift source:

- `/Volumes/Plutonian/_Developer/Deconstructed/references/ComponentExploration/Sources/ComponentExploration/MyComponent.swift`

## Exact Mapping Extracted So Far

## General

1. Accessibility -> prim `Accessibility`, id `RealityKit.Accessibility`, parent `/Root/Cube`, nested struct: no
2. Anchoring -> prim `Anchoring`, id `RealityKit.Anchoring`, parent `/Root/Cube`, nested struct: yes (`descriptor`)
3. Animation Library -> prim `AnimationLibrary`, id `RealityKit.AnimationLibrary`, parent `/Root/Cube`, nested struct: no
4. Behaviors -> prim `RCP_BehaviorsContainer`, id `RCP.BehaviorsContainer`, parent `/Root/Cube`, nested struct: no
5. Billboard -> prim `Billboard`, id `RealityKit.Billboard`, parent `/Root/Cube`, nested struct: no
6. Character Controller -> prim `CharacterController`, id `RealityKit.CharacterController`, parent `/Root/Cube`, nested struct: yes
7. Docking Region -> prim `CustomDockingRegion`, id `RealityKit.CustomDockingRegion`, parent `/Root/Cube`, nested struct: yes (`m_bounds`)
8. Input Target -> prim `InputTarget`, id `RealityKit.InputTarget`, parent `/Root/Cube`, nested struct: no
9. Model Sorting -> prim `MeshSorting`, id `RealityKit.MeshSorting`, parent `/Root/Cube`, nested struct: no
10. Opacity -> prim `HierarchicalFade`, id `RealityKit.HierarchicalFade`, parent `/Root/Cube`, nested struct: no
11. Particle Emitter -> prim `VFXEmitter`, id `RealityKit.VFXEmitter`, parent `/Root/Cube`, nested struct: yes
12. Scene Understanding -> prim `SceneUnderstanding`, id `RealityKit.SceneUnderstanding`, parent `/Root`, nested struct: no

## Audio

1. Audio Library -> prim `AudioLibrary`, id `RealityKit.AudioLibrary`, nested struct: no
2. Spatial Audio -> prim `SpatialAudio`, id `RealityKit.SpatialAudio`, nested struct: no
3. Ambient Audio -> prim `AmbientAudio`, id `RealityKit.AmbientAudio`, nested struct: no
4. Channel Audio -> prim `ChannelAudio`, id `RealityKit.ChannelAudio`, nested struct: no
5. Audio Mix Groups -> prim `AudioMixGroups`, id `RealityKit.AudioMixGroups`, nested struct: no
6. Reverb -> prim `Reverb`, id `RealityKit.Reverb`, nested struct: no

## Lighting

1. Directional Light -> prim `DirectionalLight`, id `RealityKit.DirectionalLight`, nested struct: yes (`Shadow`)
2. Environment Lighting Configuration -> prim `EnvironmentLightingConfiguration`, id `RealityKit.EnvironmentLightingConfiguration`, nested struct: no
3. Grounding Shadow -> prim `GroundingShadow`, id `RealityKit.GroundingShadow`, nested struct: no
4. Image Based Light -> prim `ImageBasedLight`, id `RealityKit.ImageBasedLight`, nested struct: no
5. Image Based Light Receiver -> prim `ImageBasedLightReceiver`, id `RealityKit.ImageBasedLightReceiver`, nested struct: no
6. Point Light -> prim `PointLight`, id `RealityKit.PointLight`, nested struct: no
7. Spot Light -> prim `SpotLight`, id `RealityKit.SpotLight`, nested struct: yes (`Shadow`)
8. Virtual Environment Probe -> prim `VirtualEnvironmentProbe`, id `RealityKit.VirtualEnvironmentProbe`, nested struct: yes (`Resource1`/`Resource2`)

## Physics

1. Collision -> prim `Collider`, id `RealityKit.Collider`, nested struct: yes (`Shape` + nested `pose`)
2. Physics Body -> prim `RigidBody`, id `RealityKit.RigidBody`, nested struct: yes (`massFrame`, `material`, nested `m_pose`)
3. Physics Motion -> prim `MotionState`, id `RealityKit.MotionState`, nested struct: no

## Deconstructed Changes Completed

All edits live in workspace:

- `/Volumes/Plutonian/_Developer/Deconstructed/source/Deconstructed`

Implemented modules/files:

1. `Packages/DeconstructedLibrary/Sources/InspectorModels/ComponentCatalog.swift`
2. `Packages/DeconstructedLibrary/Sources/InspectorModels/SharedSelectionState.swift`
3. `Packages/DeconstructedLibrary/Sources/InspectorUI/InspectorView.swift`
4. `Packages/DeconstructedLibrary/Sources/InspectorFeature/InspectorFeature.swift`
5. `Packages/DeconstructedLibrary/Sources/DeconstructedUSDInterop/DeconstructedUSDInterop.swift`
6. `Packages/DeconstructedLibrary/Sources/DeconstructedFeatures/DocumentEditorFeature.swift`

### Implemented behavior

1. Added `Components` section in inspector.
2. Added grouped Add Component menu (General/Audio/Lighting/Physics).
3. Added component catalog with extracted names and IDs.
4. Added initial authoring action path in inspector reducer.
5. Added USDA writer path for component insertion:
   - writes component block under target prim
   - currently USDA-focused for MVP
6. Added viewport/scene graph/project browser refresh after successful add.
7. Added placement handling:
   - default: selected prim
   - Scene Understanding: root prim

## Current Enablement Status

### Enabled for add-authoring now

1. Accessibility
2. Anchoring
2. Animation Library
3. Behaviors
4. Billboard
5. Character Controller
6. Docking Region
5. Input Target
6. Model Sorting
7. Opacity
8. Particle Emitter
8. Scene Understanding
9. Audio Library
10. Spatial Audio
11. Ambient Audio
12. Channel Audio
13. Audio Mix Groups
14. Reverb
15. Directional Light
15. Environment Lighting Configuration
16. Grounding Shadow
17. Image Based Light
18. Image Based Light Receiver
19. Point Light
20. Spot Light
21. Virtual Environment Probe
22. Collision
23. Physics Body
20. Physics Motion

### Listed but intentionally disabled

1. None currently for built-ins represented in local fixtures.

## Apple Schema Coverage Note

Comparing `/Users/elkraneo/Downloads/SchemaDefinitionsForThirdPartyDCCs` vs local `AppleUSDSchemas`:

1. Most `Preliminary_*` classes are implemented.
2. Missing explicit Swift struct: `Preliminary_PhysicsForce` (base class from schema file).
3. This gap does not block the current RCP inspector component authoring work.

## Open Questions / Future Research

### Custom component field type matrix

Current status:

1. Confirmed creation identity pattern (`RealityKitCustomComponent` + `info:id`).
2. Not yet confirmed authoritative supported field-type set for generated custom components.

Do not assume "any Codable works" without evidence.

Research plan:

1. Generate multiple custom components with varied field types.
2. Capture emitted USD for each case.
3. Build explicit compatibility table:
   - Swift field type
   - emitted USD type/token
   - round-trip behavior in RCP inspector
4. Identify unsupported types and failure modes.

### Selection-context validity rules

1. Implement and validate "invalid in selection" rules (e.g., Scene Understanding only on root).
2. Mirror RCP disabled-state messaging in Deconstructed menu.

### Nested struct component templates

Implemented component-specific template authoring for:

1. Lighting: Directional, Spot, Virtual Environment Probe
2. Physics: Collision, Physics Body
3. General: Anchoring, Character Controller, Docking Region, Particle Emitter

## Implementation Matrix (Current)

Legend:

1. `Add`: can be added from Add Component menu.
2. `Typed UI`: has dedicated parameter controls.
3. `Persist`: parameter edits persist via typed mapping.
4. `Fallback Raw`: raw authored attrs render/edit in generic fallback UI.

Current slice:

1. Accessibility: Add yes, Typed UI yes, Persist yes, Fallback Raw yes
2. Billboard: Add yes, Typed UI yes, Persist yes, Fallback Raw yes
3. Reverb: Add yes, Typed UI yes, Persist yes, Fallback Raw yes
4. Image Based Light: Add yes, Typed UI yes, Persist yes, Fallback Raw yes
5. Virtual Environment Probe (top-level blend mode): Add yes, Typed UI yes, Persist yes, Fallback Raw yes
6. Collision (top-level group/mask/type): Add yes, Typed UI yes, Persist yes, Fallback Raw yes
7. Point Light (color/intensity/attenuation): Add yes, Typed UI yes, Persist yes, Fallback Raw yes
8. Remaining catalog components: Add yes, Typed UI no, Persist via typed mapping no, Fallback Raw yes (top-level + descendant authored attributes)

Additional capability:

1. Inspector now loads and renders authored attributes from descendant prims under each component (for example nested `RealityKitStruct` children) and supports raw editing/persistence for those fields.

Remaining work for full parity:

1. Add typed UI + explicit mapping for remaining built-in component parameters.
2. Add editors for nested `RealityKitStruct` fields (collision shapes, rigid body nested data, light shadow blocks, etc.).
3. Implement `Remove Overrides` behavior compatible with composed USD layers.
4. Expand copy/paste semantics beyond add-by-identifier to include parameter payload transfer.
5. Complete custom component field-type matrix (Swift type <-> USD authored form <-> inspector widget).

## Authoring Strategy Decision

Decision:

1. Component insertion currently uses USDA text templates (line-based blocks) keyed by `info:id`.

Where implemented:

1. `/Volumes/Plutonian/_Developer/Deconstructed/source/Deconstructed/Packages/DeconstructedLibrary/Sources/DeconstructedUSDInterop/DeconstructedUSDInterop.swift`

Rationale:

1. Practicality and speed: we can ship parity slices quickly from verified RCP fixtures.
2. Deterministic output: easier to mirror exact RCP-authored block shapes for article-grade diffing.
3. Lower dependency risk: avoids introducing a new USD AST modeling layer while interop dependencies are still evolving.
4. Scope alignment: this phase focuses on inspector authoring parity, not generalized USD rewriting.

Why not AST (for now):

1. `swift-syntax` is not relevant here because this is USDA authoring, not Swift source transformation.
2. A robust USD AST pipeline would require additional typed modeling/writer infrastructure (or deeper OpenUSD mutation APIs) that is larger than current milestone scope.
3. For current component operations, fixed-schema template insertion is sufficient and testable against fixture files.

Known limitations of template approach:

1. Sensitive to formatting/indent assumptions.
2. Easier to make block-shape mistakes if templates drift from fixture truth.
3. Less resilient than semantic AST edits for complex composition cases.

Upgrade path:

1. Keep fixture-driven template tests as guardrails now.
2. Migrate high-risk mutations to semantic APIs when stable interop support is available.
3. Introduce an AST/semantic writer only when template maintenance cost exceeds benefit.

## Article Outline Hooks

Suggested structure for article sections:

1. Why component parity is harder than simple schema apply.
2. Built-in vs custom component encoding (`RealityKitComponent` vs `RealityKitCustomComponent`).
3. Extracting stable IDs/prim names from real RCP projects.
4. Categorized component catalog and staged enablement strategy.
5. Handling root-only components and context-invalid entries.
6. Incremental parity: simple components first, nested-struct components second.
7. Open research: custom component field type support matrix.

## Recovered Notes From Full Thread

These notes were recovered from the full collaboration thread to avoid losing high-value context.

### Product parity/UX constraints

1. RCP-style inspector parity requires one module per component; no separate "Components module" card in the inspector body.
2. Add Component should stay as footer action (fixed placement), independent from per-component module rendering.
3. Component modules require individual lifecycle controls:
   - active/inactive toggle,
   - per-component menu (`Copy`, `Deactivate/Activate`, `Delete`, etc.),
   - disabled visual state without deleting authored data.
4. Deactivating a component should not make the module disappear; it should remain visible but disabled.
5. Viewport and hierarchy selection must remain synchronized across component mutations (selection loss was observed as a critical UX regression risk).

### Authoring model findings

1. Components are not one flat ECS shape; authored patterns include:
   - scalar fields,
   - nested structs/descendant prims,
   - resource registries,
   - cross-prim relationships,
   - graph components (Behaviors),
   - dependency-driven/UI-gated controls.
2. Behaviors are a graph container model (`RCP.BehaviorsContainer`) and not a simple parameterized component.
3. Stacked behaviors are authored in explicit order and order can change in USDA (`Stacked.usda` vs `StackedReversed.usda`).
4. Character Controller "Up Vector" currently behaves as transform-coupled authoring (orientation update), not as a dedicated component attribute in observed fixtures.
5. Docking Region preview video is authored as `customData.previewVideo` asset path and can reference external files (no observed auto-import into `.rkassets` for strict parity).
6. Docking Region can be created from both Add Component and hierarchy contextual path (`Environment > Video Dock`), implying multiple entry points to same authored structure.
7. Animation Library adds/removes entries via child `RealityKitAnimationFile` prims; Frames/Seconds toggle has no observed scene USDA delta in current fixtures.

### Research/process decisions

1. Do not assert custom component field support as "any Codable" without fixture proof; maintain explicit type matrix research as open work.
2. Template-based USDA insertion was chosen pragmatically for current phase; AST/semantic writer remains future work when maintenance cost justifies.
3. For this workspace, dependency resolution must follow workspace-local overrides (local USDInterop/USDInteropAdvanced), not inner package-only `swift build` assumptions.
4. Known build noise/blocker remains external to inspector changes in this branch: local `USDReference` / `USDAdvancedClient` API mismatch.

### Stability observations

1. RCP crash captured during Up Vector experimentation:
   - `EXC_BREAKPOINT (SIGTRAP)`,
   - `CoreRE` assertion `Bitset<64>::toWordIndex`,
   - deep AppKit layout recursion in stack.
2. Treat this as an upstream tooling instability note during reverse engineering, not necessarily an authored scene invalidation by fixture alone.
