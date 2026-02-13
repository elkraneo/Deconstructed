# Material Bindings And Textures (Phase 1)

This phase adds a minimal, RCP-aligned foundation for **material binding inspection and editing** in Deconstructed, while keeping strict dependency boundaries:

- Deconstructed UI/features do not touch low-level OpenUSD interop.
- All typed USD operations flow through `USDInteropAdvanced` and DTOs live in `USDInterfaces`.

## What We Implemented

### 1. Material Bindings Inspector (Selected Prim)

When a prim is selected, the Inspector now:

- Reads the authored `material:binding` relationship (`USDAdvancedClient.materialBinding`).
- Lists all discoverable materials in the stage (`USDAdvancedClient.allMaterials`).
- Allows setting and clearing the binding using typed editing endpoints:
  - `USDAdvancedClient.setMaterialBinding(url:primPath:materialPath:editTarget:)`
  - `USDAdvancedClient.clearMaterialBinding(url:primPath:editTarget:)`

Implementation notes:

- Deconstructed calls these APIs via `/Volumes/Plutonian/_Developer/Deconstructed/source/Deconstructed/Packages/DeconstructedLibrary/Sources/DeconstructedUSDInterop/DeconstructedUSDInterop.swift`.
- The Inspector reducer drives the async load on selection, and re-reads binding after edits.

### 2. Material Property Display (Read-Only, Best Effort)

For the currently bound material (if it exists in the material list), the Inspector displays:

- Material properties in `USDMaterialInfo.properties`.
- Texture properties (`USDMaterialProperty.PropertyValue.texture`) show:
  - A best-effort image preview if `resolvedPath` points to a readable file.
  - Otherwise the texture `url`/`resolvedPath` string for debugging.

This is intentionally **not** a shader editor yet. It is an inspection surface we can build on.

## What We Did Not Implement Yet

- Editing individual material properties (floats/colors/textures).
- Shader graph editing (MaterialX / PreviewSurface graphs).
- Robust texture resolving for packaged formats (e.g. USDZ internal textures).

Those are later steps, but the current structure keeps the architecture clean and allows us to add typed endpoints in `USDInteropAdvanced` as we need more operations.

## Interchange Note

Material interchange into RealityKit/RCP is often limited by supported shader features rather than conversion mechanics. See:

- `/Volumes/Plutonian/_Developer/Deconstructed/source/Deconstructed/Docs/MaterialX-Interchange.md`

## Why This Matches RCP’s Model

RCP’s “Material Bindings” panel maps cleanly to:

- A USD relationship on the prim (`material:binding`).
- A set of authored materials in the stage (usually `UsdShadeMaterial` prims).

The UI can remain responsive by editing only the relationship (fast), while deeper material edits require more schema-specific operations.

## Files Touched

- `/Volumes/Plutonian/_Developer/Deconstructed/source/Deconstructed/Packages/DeconstructedLibrary/Sources/InspectorFeature/InspectorFeature.swift`
- `/Volumes/Plutonian/_Developer/Deconstructed/source/Deconstructed/Packages/DeconstructedLibrary/Sources/InspectorUI/InspectorView.swift`
- `/Volumes/Plutonian/_Developer/Deconstructed/source/Deconstructed/Packages/DeconstructedLibrary/Sources/DeconstructedUSDInterop/DeconstructedUSDInterop.swift`
