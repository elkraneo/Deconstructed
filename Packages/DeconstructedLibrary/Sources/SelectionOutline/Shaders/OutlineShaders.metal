// Outline shaders for SelectionOutline package.
//
// Reserved for future use with CustomMaterial geometry modifiers
// when RealityKit exposes per-vertex normal extrusion via Metal shaders.
//
// Current implementation uses UnlitMaterial + uniform scale + front-face culling
// (inverted hull technique) which doesn't require custom Metal shaders.

#include <metal_stdlib>
using namespace metal;

// Placeholder — the outline is currently achieved via UnlitMaterial with
// faceCulling = .front and a slightly scaled-up clone of the selected mesh.
