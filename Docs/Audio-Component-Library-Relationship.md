# Audio Components and Audio Library Relationship

Last updated: 2026-02-17

## Scope

This document captures what is currently verified in USDA about:

1. `RealityKit.ChannelAudio`
2. `RealityKit.AmbientAudio`
3. `RealityKit.SpatialAudio`
4. `RealityKit.AudioLibrary`
5. `RealityKitAudioFile`

The goal is to describe where "Preview > Resource" appears to persist in file data, and how that should map to inspector behavior.

## Key Finding

For the current fixture set, audio preview/resource selection is persisted via:

1. `RealityKit.AudioLibrary` descendant `RealityKitDict "resources"` (`keys`, `values`)
2. `RealityKitAudioFile` prims (`file`, `shouldLoop`)

Not via a direct authored field on:

1. `RealityKit.ChannelAudio`
2. `RealityKit.AmbientAudio`
3. `RealityKit.SpatialAudio`

## Verified Scene Diffs

### Channel Audio

Compared:

1. `/Volumes/Plutonian/_Developer/Deconstructed/references/ComponentFieldExploration/Sources/ComponentFieldExploration/ComponentFieldExploration.rkassets/Channel Audio/BASE.usda`
2. `/Volumes/Plutonian/_Developer/Deconstructed/references/ComponentFieldExploration/Sources/ComponentFieldExploration/ComponentFieldExploration.rkassets/Channel Audio/Resource.usda`

Observed delta:

1. Added `RealityKitComponent "AudioLibrary"` with `info:id = "RealityKit.AudioLibrary"`
2. Added child `RealityKitDict "resources"`:
   - `string[] keys = ["1bells.wav"]`
   - `rel values = </Root/_1bells_wav>`
3. Added `RealityKitAudioFile "_1bells_wav"`:
   - `uniform asset file = @../1bells.wav@`
   - `uniform bool shouldLoop = 0`

No direct resource/preview field appears on `RealityKitComponent "ChannelAudio"`.

### Ambient Audio

Compared:

1. `/Volumes/Plutonian/_Developer/Deconstructed/references/ComponentFieldExploration/Sources/ComponentFieldExploration/ComponentFieldExploration.rkassets/Ambient Audio/BASE.usda`
2. `/Volumes/Plutonian/_Developer/Deconstructed/references/ComponentFieldExploration/Sources/ComponentFieldExploration/ComponentFieldExploration.rkassets/Ambient Audio/Resource.usda`

Observed delta follows the same pattern as Channel Audio:

1. Added Audio Library component with `resources.keys/values`
2. Added `RealityKitAudioFile "_1bells_wav"`

No direct resource/preview field appears on `RealityKitComponent "AmbientAudio"`.

### Spatial Audio

Compared:

1. `/Volumes/Plutonian/_Developer/Deconstructed/references/ComponentFieldExploration/Sources/ComponentFieldExploration/ComponentFieldExploration.rkassets/Spatial Audio/BASE.usda`
2. `/Volumes/Plutonian/_Developer/Deconstructed/references/ComponentFieldExploration/Sources/ComponentFieldExploration/ComponentFieldExploration.rkassets/Spatial Audio/Resource.usda`

Observed delta follows the same pattern:

1. Added Audio Library component with `resources.keys/values`
2. Added `RealityKitAudioFile "_1bells_wav"`

No direct resource/preview field appears on `RealityKitComponent "SpatialAudio"`.

## `Channel Audio/ALL.usda` Verification

File:

1. `/Volumes/Plutonian/_Developer/Deconstructed/references/ComponentFieldExploration/Sources/ComponentFieldExploration/ComponentFieldExploration.rkassets/Channel Audio/ALL.usda`

Observed authored data:

1. `ChannelAudio` has:
   - `float gain = -21.279995`
   - `uniform token info:id = "RealityKit.ChannelAudio"`
2. `AudioLibrary` has:
   - `string[] keys = ["1bells.wav"]`
   - `rel values = </Root/_1bells_wav>`
3. `RealityKitAudioFile "_1bells_wav"` has:
   - `uniform asset file = @../1bells.wav@`
   - `uniform bool shouldLoop = 0`

Conclusion: even in `ALL.usda`, the selected preview resource is still represented through Audio Library + AudioFile, not as a dedicated field on `ChannelAudio`.

## Practical Model for Deconstructed

### Data ownership (current best model)

1. Audio component fields (`gain`, `directLevel`, `reverbLevel`, etc.) are authored on the audio component prim.
2. Resource inventory and target mapping are authored in Audio Library resources (`keys`, `values`).
3. File path and loop metadata are authored on `RealityKitAudioFile` prims.

### Inspector implications

1. `Audio Library` component should display and manage resource inventory (`keys`, `values`) and file entries.
2. `Channel/Spatial/Ambient` inspector may expose a `Preview > Resource` affordance using the shared Audio Library resource list.
3. Until a direct authored binding field is discovered, that preview selector should be treated as UI selection state unless proven to author another USD field.

## Known Limits

1. Evidence is from the fixture set under `/Volumes/Plutonian/_Developer/Deconstructed/references/ComponentFieldExploration`.
2. It is still possible that other RCP operations author additional linkage fields in scenes not yet captured.

## Next Verification Steps

1. Capture a sequence where only Preview Resource changes repeatedly while all other audio fields remain constant.
2. Diff:
   - component prim (`ChannelAudio`, `AmbientAudio`, `SpatialAudio`)
   - `AudioLibrary/resources`
   - `RealityKitAudioFile` prims
3. Check non-USDA project metadata (`Package.realitycomposerpro/WorkspaceData/*`) for extra UI-only persisted selection state.
