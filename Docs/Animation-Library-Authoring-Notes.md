# Animation Library Authoring Notes

Last updated: 2026-02-19

Fixture source:
- `/Volumes/Plutonian/_Developer/Deconstructed/references/ComponentFieldExploration/Sources/ComponentFieldExploration/ComponentFieldExploration.rkassets/Animation Library`

## Observed USDA Pattern

`RealityKit.AnimationLibrary` is authored as a component prim:

```usda
def RealityKitComponent "AnimationLibrary"
{
    uniform token info:id = "RealityKit.AnimationLibrary"
}
```

Animation entries are authored as child prims under that component:

```usda
def RealityKitAnimationFile "<prim_name>"
{
    uniform asset file = @../clip.usdc@
    uniform string name = "clip"
}
```

## Add/Remove Behavior

From fixture diffs:
- `AddOne.usda`: one `RealityKitAnimationFile` child.
- `AddTwo.usda`: two `RealityKitAnimationFile` children.
- `RemoveOne.usda`: one child removed by deleting that child prim.

## Units Toggle

`UnitsSeconds.usda` vs `BASE.usda` shows no authored scene delta.

Interpretation:
- Frames/Seconds appears to be inspector/runtime/UI metadata.
- It is not currently scene-authored in the tested fixtures.

## Missing Resource Case

`MissingResource.usda` still authors the same child structure (`file` + `name`).
No dedicated authored "invalid" flag was observed.

Interpretation:
- Missing resource is likely detected during resolution/playback, not by extra USDA fields.

## Deconstructed Implementation Decision

Inspector module for `RealityKit.AnimationLibrary` should:
- Render a list of `RealityKitAnimationFile` children.
- Add entries by creating a new `RealityKitAnimationFile` child under the component and writing:
  - `uniform asset file`
  - `uniform string name`
- Remove entries by deleting the selected child prim.
- Treat Frames/Seconds as non-authored for now unless future fixtures show serialized metadata.

Current implementation location:
- `/Volumes/Plutonian/_Developer/Deconstructed/source/Deconstructed/Packages/DeconstructedLibrary/Sources/InspectorFeature/InspectorFeature.swift`
- `/Volumes/Plutonian/_Developer/Deconstructed/source/Deconstructed/Packages/DeconstructedLibrary/Sources/InspectorUI/InspectorView.swift`

Current implementation scope:
- Supports list/add/remove of animation resources.
- Imports source files into the current `.rkassets` tree before authoring the `asset` path.
- Uses child-prim authoring (`RealityKitAnimationFile`) as observed in RCP fixtures.
- Does not yet implement transport/timeline controls (play/stop/scrub) from RCP UI.

## Open Questions For Future Research

1. Whether timeline unit preference is authored in workspace/user metadata instead of scene USDA.
2. Whether duplicate `name` values have special runtime resolution behavior.
3. Whether `name` must match timeline action labels exactly or is only display text.
4. Additional behavior when referenced animation file prim paths differ from entity/skeleton binding expectations.
