# MaterialX, UsdPreviewSurface, And RealityKit Interchange

## Summary

When moving materials from DCC tools (for example Houdini MaterialX/MatX) into Reality Composer Pro (RCP) / RealityKit, the limiting factor is usually **RealityKit's supported shader feature set**, not the ability to "convert MaterialX."

RealityKit and RCP can consume USD materials, but only a subset of shading models and node networks will evaluate the same way across tools.

## Why "Conversion" Is Not The Hard Part

MaterialX can be represented in USD in multiple ways (for example via `UsdShade` networks and/or MaterialX-related outputs). Translating an `.mtlx` graph into a USD encoding is doable, but:

- DCC-authored graphs frequently use nodes/features that do not exist in RealityKit's supported subset.
- Even when nodes exist, their semantics, available inputs, and evaluation may differ across renderers.

So a "converter" can successfully write a USD file that is syntactically correct, but the result may still not render in RealityKit/RCP as intended.

## Most Stable Interchange Baseline: UsdPreviewSurface (Metallic Workflow)

If the goal is "works through RCP and is broadly portable," the most conservative baseline is:

- Author a **metallic PBR workflow** material.
- Encode it as **UsdPreviewSurface** with texture-driven inputs where applicable.

This recommendation matches the design intent of UsdPreviewSurface: it is explicitly a constrained PBR surface meant to promote "reliable interchange" across DCCs and real-time clients.

References:

- UsdPreviewSurface spec (goal: preview material for interchange):
  - https://openusd.org/dev/spec_usdpreviewsurface.html
- Apple guidance (for maximum compatibility, use metallic workflow; points to UsdPreviewSurface for example implementations):
  - https://developer.apple.com/documentation/usd/creating-usd-files-for-apple-devices
- Apple renderer mapping (RealityKit renderer handles drawing for Reality Composer Pro):
  - https://developer.apple.com/documentation/usd/creating-usd-files-for-apple-devices

## Practical Workflow

- Keep a "portable" UsdPreviewSurface material as the baseline (what you expect to survive across tools).
- Treat RealityKit/RCP-specific shading networks as an enhancement layer (what you expect to look best in RealityKit, but not necessarily round-trip).
- For complex DCC materials: bake procedural components down to textures, then wire those into UsdPreviewSurface inputs.

## Suggested Public Wording

"Conversion isn't really the blocker. The blocker is that RealityKit/RCP only evaluates a relatively small, opinionated subset of shading networks. The most stable path for porting materials through RCP is to target the metallic PBR workflow via UsdPreviewSurface (plus baked textures), and then rebuild or enhance inside RealityKit where needed."

