# Particle Emitter - Verified Field Matrix

**Component ID:** `RealityKit.VFXEmitter`  
**Source fixture set:** `/Volumes/Plutonian/_Developer/Deconstructed/source/RCPComponentDiffFixtures/Sources/RCPComponentDiffFixtures/RCPComponentDiffFixtures.rkassets/Particle Emitter/`  
**Total fixtures:** 107 files  
**Last updated:** 2026-03-19

---

## Schema Structure

Particle Emitter authoring is split across two nested struct levels inside the `RealityKit.VFXEmitter` component prim:

- `currentState` stores the controls shown in the **Emitter** tab.
- `mainEmitter` stores the primary particle stream shown in the **Particles** tab.
- `spawnedEmitter` stores the secondary particle stream. It mirrors `mainEmitter` and is only relevant when secondary spawning is enabled.

This is the authored USD layout observed in the fixtures:

```
def RealityKitComponent "VFXEmitter" {
    uniform token info:id = "RealityKit.VFXEmitter"
    
    def RealityKitStruct "currentState" {
        // Emitter Tab fields (direct on currentState)
        
        def RealityKitStruct "mainEmitter" {
            // Particles Tab fields (primary emitter)
        }
        
        def RealityKitStruct "spawnedEmitter" {
            // Secondary emitter (same schema as mainEmitter)
        }
    }
}
```

Practical implications:

- Do not expect particle fields like `birthRate` or `startColorA` directly on `VFXEmitter`; they live under `currentState.mainEmitter` or `currentState.spawnedEmitter`.
- Do not expect emitter-wide controls like `loops` or `emitterShape` inside `mainEmitter`; they stay on `currentState`.
- `spawnedEmitter` is not a different schema. It is the same particle-field schema applied to the secondary stream.

---

## Emitter Tab Fields (currentState)

### Timing Section

| UI Label | Field Name | Type | Default | Notes |
|----------|------------|------|---------|-------|
| Loop | `loops` | `bool` | `1` (ON) | Toggle looping |
| Emission Duration | `emissionDuration` | `double` | — | Seconds |
| Emission Duration Variation | `emissionDurationVariation` | `double` | — | Always authored with duration |
| Idle Duration | `idleDuration` | `double` | — | Seconds between loops |
| Warmup Duration | `warmupDuration` | `double` | — | Pre-simulation time |
| Speed | `simulationSpeed` | `double` | — | Playback speed multiplier |

### Shape Section

| UI Label | Field Name | Type | Default | Notes |
|----------|------------|------|---------|-------|
| Emitter Shape | `emitterShape` | `token` | `"Plane"` | See shape options below |
| Radial Amount | `radialAmount` | `float` | — | Radians. Shape-specific |
| Torus Inner Radius | `torusInnerRadius` | `float` | — | Only for Torus shape |
| Birth Location | `birthLocation` | `token` | `"Surface"` | `"Surface"`, `"Volume"`, `"Vertices"` |
| Birth Direction | `birthDirection` | `token` | `"Normal"` | `"Normal"`, `"World"`, `"Local"` |
| Emitter Shape Size | `shapeSize` | `float3` | — | Vector (x, y, z) |
| Particles in Local Space | `isLocal` | `bool` | `0` (OFF) | Toggle |
| Fields in Local Space | `simulationInLocalSpace` | `bool` | `0` (OFF) | Toggle |

**Emitter Shape Options:**
- `"Box"`
- `"Sphere"` (+ `radialAmount`)
- `"Cone"` (+ `radialAmount`)
- `"Cylinder"` (+ `radialAmount`)
- `"Plane"`
- `"Point"`
- `"Torus"` (+ `torusInnerRadius`, + `radialAmount`)

### Spawning Section

| UI Label | Field Name | Type | Default | Notes |
|----------|------------|------|---------|-------|
| Spawn Occasion | `spawnOccasion` | `token` | `"OnDeath"` | `"OnBirth"`, `"OnDeath"`, `"OnUpdate"` |
| Spawn Velocity Factor | `spawnVelocityFactor` | `float` | — | Multiplier |
| Spawn Spread Factor | `spawnSpreadFactor` | `float` | — | Radians |
| Spawn Spread Factor Variation | `spawnSpreadFactorVariation` | `float` | — | Radians |
| Inherit Color | `spawnInheritParentColor` | `bool` | `0` (OFF) | Toggle |

---

## Particles Tab Fields (mainEmitter)

### Main Section

| UI Label | Field Name | Type | Default | Notes |
|----------|------------|------|---------|-------|
| Birth Rate | `birthRate` | `float` | — | Particles per second |
| Birth Rate Variation | `birthRateVariation` | `float` | — | |
| Burst Count | `burstCount` | `int` | — | For burst mode |
| Burst Count Variation | `burstCountVariation` | `int` | — | |

### Properties Section

| UI Label | Field Name | Type | Default | Notes |
|----------|------------|------|---------|-------|
| Life Span | `particleLifeSpan` | `double` | — | Seconds |
| Life Span Variation | `particleLifeSpanVariation` | `double` | — | |
| Size | `particleSize` | `float` | — | Base size |
| Size Variation | `particleSizeVariation` | `float` | — | |
| Size Over Life | `sizeOverLife` | `float` | — | End of life multiplier |
| Size Over Life Power | `sizeOverLifePower` | `float` | — | Curve power |
| Mass | `particleMass` | `float` | — | Grams |
| Mass Variation | `particleMassVariation` | `float` | — | |
| Orientation Mode | `billboardMode` | `token` | `"Billboard"` | See orientation options |
| Angle | `particleAngle` | `float` | — | Degrees (stored as radians) |
| Angle Variation | `particleAngleVariation` | `float` | — | Degrees (stored as radians) |
| Stretch Factor | `stretchFactor` | `float` | — | |

**Orientation Mode Options:**
- `"Billboard"` - Face camera
- `"BillboardYAligned"` - Face camera, Y-axis aligned
- `"Free"` - No billboard

### Color Section

| UI Label | Field Name | Type | Default | Notes |
|----------|------------|------|---------|-------|
| Start Color A | `startColorA` | `float4` | — | RGBA |
| Start Color B | `startColorB` | `float4` | — | For range mode |
| Use Start Color Range | `useStartColorRange` | `bool` | `0` | Toggle range mode |
| End Color A | `endColorA` | `float4` | — | RGBA |
| End Color B | `endColorB` | `float4` | — | For range mode |
| Use End Color | `useEndColor` | `bool` | `0` | Enable end color |
| Use End Color Range | `useEndColorRange` | `bool` | `0` | Toggle range mode |
| Color Evolution Power | `colorEvolutionPower` | `float` | — | |
| Opacity Over Life Mode | `opacityOverLife` | `token` | `"QuickFadeInOut"` | See opacity options |

**Opacity Over Life Options:**
- `"Constant"`
- `"EaseFadeIn"`
- `"EaseFadeOut"`
- `"GradualFadeInOut"`
- `"LinearFadeIn"`
- `"LinearFadeOut"`
- `"QuickFadeInOut"`

### Textures Section

| UI Label | Field Name | Type | Default | Notes |
|----------|------------|------|---------|-------|
| Particle Image | `particleImage` | `asset` | — | Path to texture |
| Blend Mode | `blendMode` | `token` | `"Alpha"` | `"Alpha"`, `"Additive"`, `"Opaque"` |

### Textures/Animation Section

| UI Label | Field Name | Type | Default | Notes |
|----------|------------|------|---------|-------|
| Is Animated | `isAnimated` | `bool` | `0` | Enable sprite animation |
| Frame Rate | `frameRate` | `float` | — | Frames per second |
| Frame Rate Variation | `frameRateVariation` | `float` | — | |
| Initial Frame | `initialFrame` | `int64` | — | Starting frame |
| Initial Frame Variation | `initialFrameVariation` | `int64` | — | |
| Row Count | `rowCount` | `int64` | — | Sprite sheet rows |
| Column Count | `columnCount` | `int64` | — | Sprite sheet columns |
| Animation Repeat Mode | `animationRepeatMode` | `token` | — | See animation options |

**Animation Repeat Mode Options:**
- `"Looping"`
- `"AutoReverse"`
- `"PlayOnce"`

### Motion Section

| UI Label | Field Name | Type | Default | Notes |
|----------|------------|------|---------|-------|
| Acceleration | `acceleration` | `float3` | — | Vector (x, y, z) |
| Drag | `dampingFactor` | `float` | — | UI calls it "Drag" |
| Spreading Angle | `spreadingAngle` | `float` | — | Radians |
| Angular Velocity | `particleAngularVelocity` | `float` | — | Rad/s |
| Angular Velocity Variation | `particleAngularVelocityVariation` | `float` | — | Rad/s |

### Rendering Section

| UI Label | Field Name | Type | Default | Notes |
|----------|------------|------|---------|-------|
| Lighting Enabled | `isLightingEnabled` | `bool` | `0` | Toggle lighting |
| Sort Order | `sortOrder` | `token` | `"Unsorted"` | See sort options |

**Sort Order Options:**
- `"Unsorted"`
- `"IncreasingID"`
- `"DecreasingID"`
- `"IncreasingAge"`
- `"DecreasingAge"`
- `"IncreasingDepth"`
- `"DecreasingDepth"`

### Force Fields Section

| UI Label | Field Name | Type | Default | Notes |
|----------|------------|------|---------|-------|
| Attraction Center | `radialGravityCenter` | `float3` | — | Position vector |
| Attraction Strength | `radialGravityStrength` | `float` | — | |
| Vortex Direction | `vortexDirection` | `float3` | — | Vector (x, y, z) |
| Vortex Strength | `vortexStrength` | `float` | — | |
| Noise Strength | `noiseStrength` | `float` | — | |
| Noise Scale | `noiseScale` | `float` | — | |
| Noise Animation Speed | `noiseAnimationSpeed` | `float` | — | |

---

## Secondary Emitter (spawnedEmitter)

`spawnedEmitter` uses the same authored field set as `mainEmitter`. The only extra control required to activate it is the toggle on `currentState`:

| UI Control | Field Name | Type | Notes |
|------------|------------|------|-------|
| Secondary Emitter Enabled | `isSpawningEnabled` | `bool` | On `currentState`, not inside struct |

Once `isSpawningEnabled` is authored, any field from the **Particles Tab Fields** sections above can also appear inside `spawnedEmitter`.

---

## Authoring Notes

1. Default-state controls are often omitted. Many fixtures only author a field after the user changes it away from the baseline value.
2. Variation controls are usually not standalone. When RCP writes a variation field, it typically writes the corresponding base field in the same edit.
3. Shape-specific fields are conditional. `torusInnerRadius` only appears for `Torus`, and `radialAmount` only appears for shapes that expose a radial control.
4. Animation fields depend on texture setup. The animation block is only meaningful once `particleImage` is present and sprite animation is enabled.
5. Secondary particle data is gated by `isSpawningEnabled`. Without that toggle, `spawnedEmitter` may be absent or remain effectively unused even though it shares the primary emitter schema.

---

## Implementation Checklist

- [ ] Emitter Tab inspector (currentState fields)
- [ ] Particles Tab inspector (mainEmitter fields)
- [ ] Emitter dropdown (switch between mainEmitter/spawnedEmitter)
- [ ] Secondary emitter enable/disable
- [ ] Shape-specific conditional fields
- [ ] Color range mode toggles
- [ ] Sprite animation conditional fields
- [ ] All token enums mapped to UI options
- [ ] Float3 fields use vector inputs
- [ ] Float4 color fields use color pickers
- [ ] Asset fields use file pickers
- [ ] Angle fields convert degrees ↔ radians

---

## Related Files

- **Fixtures:** `RCPComponentDiffFixtures/Sources/RCPComponentDiffFixtures/RCPComponentDiffFixtures.rkassets/Particle Emitter/`
- **Secondary:** `Secondary Emitter All.usda` - Shows complete spawnedEmitter schema
- **BASE:** `BASE.usda` - Default state
- **Tab Particles:** `Tab Particles.usda` - Empty mainEmitter (default particles state)
