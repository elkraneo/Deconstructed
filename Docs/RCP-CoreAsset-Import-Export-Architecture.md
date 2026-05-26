# RCP CoreAsset Import/Export Architecture

> **Consolidated Research Document**
>
> This document merges findings from Hopper decompilation of Apple's `CoreAsset.framework` (macOS 26 Tahoe), empirical testing with RealityKit's `Entity(contentsOf:)`, and analysis of RCP reference projects.
>
> Sources consolidated: `Decompilation_Findings_CoreAsset.md`, `Prim_Entity_Mapping_Heuristics.md`, `Docs/RCP-Entity-Prim-Mapping.md`, `RCP_TRANSFORM_PHASE_NOTES.md`

---

## Table of Contents

1. [Architecture Layers](#1-architecture-layers)
2. [The Import Pipeline](#2-the-import-pipeline)
3. [The Export Pipeline](#3-the-export-pipeline)
4. [Transform Storage Model](#4-transform-storage-model)
5. [USD Property Mapping (xformOps)](#5-usd-property-mapping-xformops)
6. [Entity Hierarchy Construction](#6-entity-hierarchy-construction)
7. [Prim↔Entity Mapping](#7-primentity-mapping)
8. [Selection Resolution Heuristics](#8-selection-resolution-heuristics)
9. [Key Data Structures](#9-key-data-structures)
10. [C Function Imports](#10-c-function-imports)
11. [Warning/Error Strings](#11-warningerror-strings)
12. [Deconstructed Implementation Guidance](#12-deconstructed-implementation-guidance)
13. [Appendix: Address Reference](#13-appendix-address-reference)

---

## 1. Architecture Layers

The CoreAsset framework implements a **three-layer stack** that bridges USD files to RealityKit entities:

```
┌──────────────────────────────────────────────────────────┐
│                    USD Layer (RealityIO)                  │
│  RealityIO.Prim, SceneDescriptionFoundations.Path, Stage  │
│  ImportSession — primPath(of:), prim(of:), entity(at:)   │
└───────────────────────┬──────────────────────────────────┘
                        │
                        ▼
┌──────────────────────────────────────────────────────────┐
│             Prim Descriptor Layer (CoreAsset)             │
│  USKScene / USKNode — ObjC++ wrappers around pxr::UsdStage│
│  PrimNodeSpecification — sourcePrimPath, referencedPrimPath│
│  RESceneImportOperation — preFlight → run → publish      │
└───────────────────────┬──────────────────────────────────┘
                        │
                        ▼
┌──────────────────────────────────────────────────────────┐
│           Bridge Layer (CoreAsset / RE C++ API)           │
│  REEntity — holds runtimeIdentifier: UUID + entity handle│
│  RETransformComponent — localPose + localScale (SPLIT!)  │
│  convertToRealityKitEntity() → RealityKit.Entity (lazy)  │
└───────────────────────┬──────────────────────────────────┘
                        │
                        ▼
┌──────────────────────────────────────────────────────────┐
│             Runtime Layer (RealityKit)                    │
│  Entity with TransformComponent (single 4x4 matrix)      │
│  ModelComponent, SynchronizationComponent, etc.          │
└──────────────────────────────────────────────────────────┘
```

### Layer 1: USKScene/USKNode (C++ USD Wrapper)

Confirmed via Hopper at addresses around `0x34634` and `0x32138`. These are ObjC++ wrappers around `pxr::UsdStage`:

| Symbol | Address | Purpose |
|--------|---------|---------|
| `USKScene.load(from:)` | `0x34634` | Loads .usda/.usdc/.usdz into a scene |
| `USKScene.newNodeAtPath:type:` | — | Creates a USD prim at a given path |
| `USKScene.findNode(path:)` | `0x34fd4` | Finds existing prims by object path |
| `USKScene.addNode(name:parent:type:)` | `0x32138` | Adds a named node under a parent |
| `USKScene.addNode(path:type:)` | `0x34878` | Adds a node at a specific path |
| `USKScene.getOrAddNode(name:parent:type:)` | `0x3498c` | Gets or creates a node |
| `USKScene.metersPerUnit` | `0x34590` | Reads stage metadata |
| `USKScene.timeCodesPerSecond` | `0x34504` | Reads timeCodesPerSecond metadata |
| `USKScene.MetadataKeys` | `0x33d98+` | Constants: metersPerUnit, upAxis, defaultPrim, etc. |
| `USKScene.makeTexturesCompatibleWithUSDZ` | `0x1579d0` | Texture conversion for USDZ |
| `USKScene.remapTexturesIfInUSDZ` | `0x15804c` | Texture remapping for USDZ |

Supported file types (from strings at `0x2e2a85-0x2e2a8f`):
```
obj, usdz, usdc, usda, jpg, png
```

#### USKNode (the USD prim wrapper)

| Symbol | Address | Purpose |
|--------|---------|---------|
| `USKNode.set(scale:orientation:translation:)` | `0x3239c` | **Creates xformOp properties on the USD prim** |
| `USKNode.addProperty(name:type:role:)` | `0x322d0` | Adds arbitrary USD property |
| `USKNode.findProperty(name:)` | `0x34084` | Finds existing USD property |
| `USKNode.newPropertyWithName:type:role:` | — | Creates property (ObjC) |
| `USKNode.getMeshBoundingBox()` | `0x32cd8` | Bounding box query |
| `USKNode.getExtentsBoundingBox()` | `0x32eb0` | Extents query |
| `USKNode.getBBox(atTime:except:)` | `0x330a8` | Time-dependent bounding box |
| `USKNode.hasText` | `0x33db4` | Texture presence check |
| `USKNode.setSpecifier:` | — | Sets `over` vs `def` specifier |

### Layer 2: RESceneImportOperation (Orchestration)

Confirmed at `0x15e3c0`-`0x15e50c`. The main import operation with **3-phase lifecycle**:

```
preFlight()   → _RESceneImportOperationPreflight  (C++ thunk)
run()         → _RESceneImportOperationRun         (C++ thunk)
publishToEngine() → RESceneImportOperationGetSceneAsset → REAsset
```

Configuration options (setters at `0x15e25c`-`0x15e360`):

| Setter | Type | Purpose |
|--------|------|---------|
| `setIsolatefromEngine(_: Bool)` | Bool | Isolate from engine |
| `setCompressTextures(_: Bool)` | Bool | Compress textures on import |
| `setMergeIntoSingleEntity(_: Bool)` | Bool | **Flatten hierarchy into single entity** |
| `setPlayDefaultAnimationsImmediately(_: Bool)` | Bool | Auto-play |
| `setGenerateDecimatedMeshes(_: Bool)` | Bool | LOD generation |
| `setOptimizeMeshesForVertexCaching(_: Bool)` | Bool | Vertex cache optimization |
| `setUnpackagedTextureMode(_:) ` | enum | Texture unpackaging |
| `setUnitType(_:)` | USKUnitType | Unit conversion |

### Layer 3: REEntity (Runtime Entity Bridge)

Confirmed at `0x15cb9c`-`0x15d8f0`. The critical Swift wrapper around the C++ RE entity handle:

```swift
class REEntity {
    // offset [0x3]: lazily cached RealityKit Entity (nil until first convertToRealityKit())
    var runtimeIdentifier: UUID?           // stable UUID — survives convertToRealityKit()
    var name: String                       // set via REEntitySetName()
    var parent: REEntity?                  // set via REEntitySetParent()
    var children: [REEntity]               // from REEntityGetChildren()
    var mesh: OpaquePointer?               // C-level mesh handle
    var materials: [OpaquePointer]         // material handles
    var isSelfActive: Bool                 // from REEntityGetSelfEnabled()
    var interactions: [__RKEntityInteractionSpecification]
    var arAnchorSpecification: __REAnchoringType?
    var tags: [String]
    var scene: REScene?                    // owning scene
    var filterMapMaterials: OpaquePointer? // material filter map
}
```

Key methods:

| Method | Address | Purpose |
|--------|---------|---------|
| `init(OpaquePointer)` | `0x15cb9c` | Wraps a C++ RE entity handle |
| `convertToRealityKitEntity()` | `0x15d548` | Lazily creates/caches RealityKit Entity |
| `setTransform(Transform)` | `0x15c508` | Sets transform via RE C API |
| `getTransform()` | `0x15d638` | Reads transform via RE C API (delegates to `sub_160058`) |
| `getTransformMatrix()` | `0x1623c4` | Returns `simd_float4x4` |
| `isValid(transform:)` | `0x15ff78` | Validates quaternion decomposition |
| `copy(recursive:)` | `0x15fce0` | Deep copy entity tree |

---

## 2. The Import Pipeline

### Entry Point: `RESceneImportOperation`

```
URL → RESceneImportOperation.createWithURL(url:serviceLocator:)
   → preFlight()                    (validates, reserves resources)
   → run()                          (parses USD, builds entity tree)
   → publishToEngine()              (publishes to RE engine)
   → getSceneAsset() → REAsset      (the loaded scene)
   → getSceneHierarchy() → REScene  (the entity tree)
```

The `run()` method (`0x15e3c0`) is a thin Swift wrapper that calls the C function `_RESceneImportOperationRun`. The actual import heavy lifting happens in the C++ layer.

### Detailed Import Flow

```
USKScene.load(from: URL)
    ↓
RESceneImportOperation.preFlight()     → _RESceneImportOperationPreflight (C++)
RESceneImportOperation.run()           → _RESceneImportOperationRun (C++)
    ↓
USKScene → traverses USD prims → creates USKNode hierarchy
    ↓
FileImportBuilderFactory.initialSceneTransform(for:with:afContext:) (0x143608)
    → Reads URL from Parameters
    → Checks "includeSceneScaling" and "withDescendants" flags
    → Creates ImportRealityBuilder via Evaluator.generate(with:context:)
        ↓
    ImportRealityBuilder builds REEntity hierarchy from USKScene
    Each USKNode → REEntity (with sourcePrimPath stamped as runtime attribute)
        ↓
    REEntity.convertToRealityKitEntity() → RealityKit.Entity (lazy)
```

### FileImportBuilderFactory

The factory that handles actual file import logic (`0x142960`-`0x146cc0`):

| Method | Address | Purpose |
|--------|---------|---------|
| `createArguments(url:subPath:includeSceneScaling:withDescendants:)` | `0x142960` | Creates Parameters from URL |
| `initialSceneTransform(for:with:afContext:)` | `0x143608` | Creates initial entity from USD reference |
| `getImportedTransform(for:context:)` | `0x1456ac` | Resolves transform from imported scene |
| `asChildOverrides(url:afContext:childName:)` | `0x1439d8` | Creates override hierarchy for children |
| `getChildrenAsOverrides(for:parentContext:)` | `0x1440b4` | Recursive override generation |
| `canExpand(for:context:)` | `0x145190` | Checks if a scene can be expanded |
| `export(to:with:in:)` | `0x146cc0` | Exports entity to USKNode |
| `needsWrapping(url:)` | `0x143398` | Checks if wrapping is needed |
| `isRealityFile(url:)` | `0x143290` | Checks if URL is a .reality file |
| `isMicaFile(url:)` | `0x1432ec` | Checks if URL is a MICA file |
| `defaultFrameRate` | `0x142ea4` | Default animation frame rate |
| `urlParameterKey` | `0x142e58` | "url" parameter key |
| `withDescendantsKey` | `0x142e64` | "withDescendants" parameter key |

### Parameters Struct

```
Parameters {
    url: USKScene URL                  // the USD file
    subPath: String                    // sub-path within the scene
    includeSceneScaling: Bool          // propagate metersPerUnit
    withDescendants: Bool              // include children recursively
}
```

### AFContext

The asset framework context (`0x2cd880`):

```
AFContext {
    serviceLocator: REServiceLocator
    engine: REEngine?                  // optional engine reference
    engineQueue: DispatchQueue?        // queue for engine ops
    assetResolver: AssetResolver?      // URL resolution
    options: Options                   // configuration flags
    importValidator: AFImportValidating? // validation
    shaderLibraryManager: ShaderLibraryManager? // shader compilation
    mutableOptions: MutableOptions     // mutable config
    afClientContext: AFClientContext?  // interaction observation
    assetFactoryServer: AssetFactoryServer? // factory management
    generateGroupBracket: Bool
    generateGroupBracketGeneration: Bool
    disablePersistentCache: Bool
    groupAsyncGenerates: Bool
    alwaysAddProjectiveShadows: Bool
    projectiveShadowIntensity: Float
    projectiveShadowDecayRate: Float
    generateDecimatedMeshes: Bool
    optimizeMeshesForVertexCaching: Bool
}
```

---

## 3. The Export Pipeline

### Entry Point: `AFUSDExportContext`

Confirmed at `0x1e3164`:

```swift
AFUSDExportContext(
    instance: AssetFactoryHolder & HasEntity & NodeSpecification,
    scene: USKScene,                    // the USD scene being written to
    resolver: AssetResolver?,           // defaults to DefaultAssetResolver
    engineQueue: DispatchQueue?,
    temporaryDirectory: URL
)
```

### Recursive Export Flow

The function `Node.recursivelyExport(to:in:preOrder:postOrder:)` at `0x67a70`:

```
For each entity in the scene:
  1. Create USKNode with type USKNodeTypeTransform
  2. Write primSpecifier ("over" identifier) via _USKNodeSpecifierTypeOver
  3. USKNode.set(scale:orientation:translation:)  // Write transform
  4. Set "purpose" property token
  5. Invoke pre-order callback (if provided)
  6. Recurse into children
  7. Invoke post-order callback (if provided)
```

Export constants (from the decompiled code):

| Constant | Value | Purpose |
|----------|-------|---------|
| `_USKNodeTypeTransform` | (enum) | For transform-bearing prims |
| `_USKNodeSpecifierTypeOver` | (enum) | Writes `over` instead of `def` |
| `_USKDataTypeToken` | (enum) | For `purpose` property |

### ContainerFactory Export

There is also a generic export via `ContainerFactory.export(with:to:in:geometryCacheKey:materialCacheKey:)` at `0x17764` that handles container/collection exports.

### Scene Metadata Keys (from `USKScene.MetadataKeys` at `0x34448+`)

```
metersPerUnit: "metersPerUnit"
upAxis: "upAxis"
defaultPrim: "defaultPrim"
timeCodesPerSecond: "timeCodesPerSecond"
autoPlay: "autoPlay"
```

---

## 4. Transform Storage Model

The **critical finding** from the decompilation (confirmed at `0x15c508` and `0x160058`):

### The RE Runtime Uses Split Storage

The RE runtime stores transforms as **two separate components**, not a single matrix:

```
REEntity.transform = {
    localPose: simd_float4x4    // position + rotation combined (4x4 matrix)
    localScale: simd_float4x4   // scale (typically diagonal matrix)
}
```

### Reading Transform

`sub_160058` at `0x160058` — the `getTransform()` implementation:

```
1. RETransformComponentGetComponentType()       // Get transform component type ID
2. REEntityGetComponentByClass()                // Get the transform component
3. RETransformComponentGetLocalPose()            // Read 4x4 pose matrix
4. RETransformComponentGetLocalScale()           // Read scale separately
5. sub_2bf718() → combine into Transform struct (position, rotation quat, scale)
```

### Writing Transform

`REEntity.setTransform(Transform)` at `0x15c508`:

```
1. sub_15cbe8() → validate quaternion is decomposable (non-zero length check)
   - If quaternion squared length < threshold (≈0x358637bd):
       → Log warning: "Warning: trying to set a non-decomposable matrix..."
       → Skip transform
2. REEntityGetComponent() → check if transform component exists
3. REEntityAddComponent() → add RETransformComponent if missing
4. RETransformComponentSetLocalPose()           // Set position + rotation
5. RETransformComponentSetLocalScale()           // Set scale
6. RENetworkMarkComponentDirty()                 // Sync to engine
```

### Validation Logic

`REEntity.isValid(transform:)` at `0x15ff78`:

```
1. Decompose transform into scale, rotation, translation
2. Compute squared length of quaternion
3. Check if max(quatX², quatY², quatZ², quatW²) < threshold (≈1.0e-10)
4. If below threshold → reject (non-decomposable)
```

### USD ↔ RE ↔ RealityKit Representation

| Representation | Storage | Components |
|---|---|---|
| **USD** | Decomposed on prim | `xformOp:translate` (double3), `xformOp:orient` (quatf), `xformOp:scale` (double3) |
| **RE Runtime** | Split on entity | `localPose` (simd_float4x4), `localScale` (simd_float4x4) |
| **RealityKit** | Single component | `TransformComponent` (single simd_float4x4) |

### Transform Type System

From strings at `0x2cbc00` and `0x2cbc20`:

```
TransformType {
    none           → Not transformable / not a selectable prim
    posable        → Can be positioned
    drivable       → Can be animated/driven
    transform      → Full transform control
}
```

Individual axis controls (from `Parameterized`):
```
translationX, translationY, translationZ, translationXYZ
rotationX, rotationY, rotationZ, rotationXYZ
scale
```

---

## 5. USD Property Mapping (xformOps)

### Export Direction (Entity → USD)

The function `USKNode.set(scale:orientation:translation:)` at `0x3239c` is the core export path. Confirmed via decompilation:

```objc
void USKNode_setTransform(USKNode* self, simd_double3 scale, simd_quatf orientation, simd_double3 translation) {
    // Step 1: Create xformOp:translate property (type: double3)
    NSString* name = generatePropertyName();  // returns "xformOp:translate"
    USKProperty* translateProp = [self newPropertyWithName:name 
                                    type:USKDataTypeDouble3 role:nil];
    [translateProp setDouble3Value:&translation];
    
    // Step 2: Create xformOp:orient property (type: quatf)
    name = generatePropertyName();  // returns "xformOp:orient"
    USKProperty* orientProp = [self newPropertyWithName:name 
                                  type:USKDataTypeQuatf role:nil];
    [orientProp setQuatfValue:&orientation];
    
    // Step 3: Create xformOp:scale property (type: double3)
    name = generatePropertyName();  // returns "xformOp:scale"
    USKProperty* scaleProp = [self newPropertyWithName:name 
                                 type:USKDataTypeDouble3 role:nil];
    [scaleProp setDouble3Value:&scale];
    
    // Step 4: Create xformOpOrder property (type: token[])
    name = generatePropertyName();  // returns "xformOpOrder"
    USKProperty* orderProp = [self newPropertyWithName:name 
                                type:USKDataTypeTokenArray role:nil];
    [orderProp setTokenArray:@["xformOp:translate", "xformOp:orient", "xformOp:scale"]];
}
```

The resulting USD:

```usda
def Xform "MyPrim"
{
    double3 xformOp:translate = (1, 2, 3)
    quatf xformOp:orient = (1, 0, 0, 0)
    double3 xformOp:scale = (1, 1, 1)
    uniform token[] xformOpOrder = ["xformOp:translate", "xformOp:orient", "xformOp:scale"]
}
```

### Import Direction (USD → Entity)

`initialSceneTransform` at `0x143608`:

1. Extracts URL from Parameters
2. Loads the referenced USD file
3. Reads USD xformOps from the prim
4. Decomposes `xformOpOrder` into individual translate/rotate/scale components
5. Calls `sub_149df0` to create the entity hierarchy
6. Sets transform via `REEntity.setTransform()`

The SIMD matrix math in `initialSceneTransform` includes:
```
fmla v5.4s, v3.4s, v6.s[1]    // Fused multiply-add for matrix composition
fmla v5.4s, v1.4s, v6.s[2]
fmla v5.4s, v0.4s, v6.s[3]
...
```

This composes the final 4x4 transform matrix from the decomposed components.

### Verified Against RCP Reference Project

Confirmed from `/Volumes/Plutonian/_Developer/Deconstructed/references/Base/Sources/Base/Base.rkassets/Scene.usda`:

```usda
def Xform "Root"
{
    float3 xformOp:translate = (0, 0, 0)
    float3 xformOp:rotateXYZ = (0, 0, 0)
    float3 xformOp:scale = (1, 1, 1)
    uniform token[] xformOpOrder = ["xformOp:translate", "xformOp:rotateXYZ", "xformOp:scale"]
    
    def Cube "Cube" { ... }
}
```

Note: RCP itself uses `float3` and `rotateXYZ` in authored files, but the CoreAsset export code generates `double3` and `quatf`/`orient`. The difference is likely that:
- **Import/export** via CoreAsset uses decomposed quaternion representation (`orient`)
- **RCP editor** may apply additional transforms via `rotateXYZ` for UI convenience

### Live Transform Application (Deconstructed Implementation)

Based on the analysis, Deconstructed's approach is correct:

1. Apply transform immediately to the live RealityKit Entity (instant viewport feedback)
2. Persist transform to USD via `USDOperationsClient.setPrimTransform()` (write-through)
3. Viewport does NOT reload (camera stays stable)

```swift
case .inspector(.primTransformChanged(let transform)):
    // Route to viewport for instant visual feedback
    return .send(.viewport(.applyLiveTransform(LiveTransformData(
        primPath: path,
        position: transform.position,
        rotationDegrees: transform.rotationDegrees,
        scale: transform.scale
    ))))
```

Then after 120ms debounce:
```swift
try DeconstructedUSDInterop.setPrimTransform(url: url, primPath: primPath, transform: transform)
```

The comment at line L665-671 is significant:
```swift
// Do not reload the viewport here. The live update already happened.
```

---

## 6. Entity Hierarchy Construction

### Import Flow: USKNode → REEntity → RealityKit.Entity

```
USKScene.load(from: URL)
    ↓
RESceneImportOperation.preFlight()     → _RESceneImportOperationPreflight
RESceneImportOperation.run()           → _RESceneImportOperationRun
    ↓
USKScene → traverses USD prims → USKNode hierarchy
    ↓
FileImportBuilderFactory.initialSceneTransform(for:with:afContext:)
    ↓
Evaluator.generate(with:context:) → ImportRealityBuilder
    ↓
ImportRealityBuilder:
  For each USKNode in USKScene:
    1. Create REEntity wrapping C++ RE entity handle
    2. Set REEntity.name = prim name (via REEntitySetName)
    3. Set REEntity.parent (via REEntitySetParent)
    4. Stamp runtimeIdentifier (UUID) on the entity
    5. Stamp sourcePrimPath as runtime attribute
    6. Call REEntity.setTransform() from prim's xformOps
    ↓
REEntity.convertToRealityKitEntity() → RealityKit.Entity (lazy, first access)
```

### Export Flow: REEntity → USKNode → USD

```
Node.recursivelyExport(to:in:preOrder:postOrder:) (0x67a70)
    ↓
For each entity in the scene:
  1. Create USKNode with USKNodeTypeTransform
  2. Set specifier: "over" via USKNodeSpecifierTypeOver
  3. USKNode.set(scale:orientation:translation:)  ← from REEntity.getTransform()
  4. Set "purpose" property token
  5. Invoke pre-order callback
  6. Recurse into children
  7. Invoke post-order callback
```

### Empirical Verification: Entity Hierarchy = Prim Hierarchy

Tested with multiple USD files using `Entity(contentsOf:)`:

```
// Scene.usda
Entity(contentsOf: "Scene.usda") produces:

  (anonymous root wrapper)         ← Not a prim; RealityKit adds this
    Root → /Root
      Cube → /Root/Cube [mesh]
      Group → /Root/Group
        Sphere → /Root/Group/Sphere [mesh]


// ToyCar.usdz (complex asset)
Entity(contentsOf: "ToyCar.usdz") produces:

  (anonymous root wrapper)
    toy_car → /toy_car
      geom → /toy_car/geom
        realistic → /toy_car/geom/realistic
          geo → /toy_car/geom/realistic/geo
            lod0 → /toy_car/geom/realistic/geo/lod0
              toy_car_realistic_lod0 → [...]/toy_car_realistic_lod0 [mesh]
```

**Finding**: The entity tree **is** a structural mirror of the USD prim tree. Entity names match prim names exactly, with `_N` suffixes for sibling duplicates.

---

## 7. Prim↔Entity Mapping

### The Three-Way Binding

RCP does NOT rely purely on path string matching. Instead, it uses a **three-way binding**:

```
USD Prim  ────  PrimNodeSpecification  ────  REEntity
                      │                             │
                      │  stores:                     │  has runtime attributes:
                      │  • sourcePrimPath            │  • RuntimeIdentifier (UUID)
                      │  • referencedPrimPath        │  • entityName
                      │  • assetPath                 │  • sourcePrimPath
                      │  • type                      │
                      │  • transform                 │
                      ▼                             ▼
                 AnyNodeSpecification (existential wrapper)
```

### Key Data Structures

#### PrimNodeSpecification (confirmed at `0x14ce20`)

```swift
struct PrimNodeSpecification {
    // Argument keys (static computed properties)
    static var assetPathArgumentKey: String          // "assetPath"
    static var sourcePrimPathArgumentKey: String     // "sourcePrimPath" ← THE CRITICAL LINK
    static var referencedPrimPathArgumentKey: String // "referencedPrimPath" — for references
    static var typeArgumentKey: String               // "type"
    static var displayNameArgumentKey: String        // "displayName"
    static var wantDefaultMaterialKey: String        // "wantDefaultMaterial"
    static var transformOverrideExclusionsKey: String // "transformOverrideExclusions"
    
    // Data
    var transform: Transform?
    var arguments: SortedDictionary<String, ParameterTypeProtocol>
    var transformOptions: TransformOptions  // bitmask
}
```

#### TransformOptions (confirmed at `0x14d764`)

```swift
struct TransformOptions: OptionSet {
    let rawValue: Int
    static let excludeTranslation = Self(rawValue: 1 << 0)
    static let excludeRotation    = Self(rawValue: 1 << 1)
    static let excludeScale       = Self(rawValue: 1 << 2)
    
    // When ALL three are set → prim is non-selectable
    // When NONE are set → prim maps 1:1 to an entity
}
```

#### AnyNodeSpecification (confirmed at `0x14e528`)

```swift
struct AnyNodeSpecification {
    var assetFactory: (any AssetFactoryProtocol)?
    var arguments: SortedDictionary<String, ParameterTypeProtocol>
    var transform: Transform?
    var runtimeAttributes: ParameterMetadata?
    var overrides: Overrides?
}
```

#### RuntimeAttributeKeys (confirmed at `0x197058`)

Stored as runtime attributes on each `REEntity`:

```swift
enum RuntimeAttributeKeys: String {
    case RuntimeIdentifier       // UUID string — persists across sessions
    case EntityName              // "entityName" — display name
    case EntityHidden            // "entityHidden"
    case Expressions             // "Expressions"
    case Components              // "Components"
    case Interactions            // "Interactions"
    case Tags                    // "Tags"
    case LockParameters          // "LockParameters"
    case AccessibilityLabelKey   // Accessibility
    case AccessibilityDescriptionKey
    case AccessibilityEnabledKey
}
```

#### REEntity.runtimeIdentifier (confirmed at `0x2b88b8`)

```swift
class REEntity {
    var runtimeIdentifier: UUID?  // ← PERSISTENT UUID, survives re-imports
}
```

Runtime attributes are set via:
```
setRuntimeAttribute(name:value:)                    (0x1ff7c4)
setRuntimeAttribute(name:value:for:)                 (0x1fbde0)
recursivelySetRuntimeAttribute(name:value:)          (0x1ff8c0)
```

### Private API: ImportSession

RealityIO's `ImportSession` exposes the entity↔prim bridge (available via `dlsym`):

| Symbol | Signature | Purpose |
|--------|-----------|---------|
| `$s9RealityIO13ImportSessionC8primPath2ofSSSg0A3Kit6EntityC_tF` | `(Entity) -> String?` | **Get prim path from entity** |
| `$s9RealityIO13ImportSessionC4prim2ofAA4PrimCSg0A3Kit6EntityC_tF` | `(Entity) -> Prim?` | Get USD Prim from entity |
| `$s9RealityIO13ImportSessionC6entity2at0A3Kit6EntityCSgAA27...` | `(Path) -> Entity?` | Get entity by USD path |

Metadata keys retrieved via `dlsym`:

| Symbol (without `_` prefix) | Value | Purpose |
|-----|-------|---------|
| `$s9RealityIO13ImportSessionC19primPathMetadataKeySSvgZ` | `"cdm:primpath"` | Prim path metadata key |
| `$s9RealityIO13ImportSessionC23resolvedPathMetadataKeySSvgZ` | `"cdm:resolvedpath"` | Resolved path metadata key |
| `$s9RealityIO13ImportSessionC20assetInfoMetadataKeySSvgZ` | `"realitykit:assetinfo"` | Asset info metadata key |

**Limitation**: `primPath(of:)` is an **instance method** on `ImportSession`. Entities loaded via `Entity(contentsOf:)` carry **no prim path metadata** in public components — only `SynchronizationComponent`, `Transform`, and `ModelComponent`. The metadata exists only within the `ImportSession`'s internal dictionary.

### EditorObject (RealityToolsFoundation Layer)

Above CoreAsset, the `EditorObject` registry connects USD to RealityKit for RCP's editing UI:

```swift
struct EditorObject {
    var prim: RealityIO.Prim?              // USD prim reference
    var identifierPath: [String]           // hierarchical path [sceneID, name1, name2, ...]
    var objectPath: String                 // string path representation
    var coreEntity: OpaquePointer?         // direct RealityKit entity pointer
    var coreEntityID: UInt64?              // entity ID for fast lookups
}
```

Identifier path format (from error strings):
```
[sceneID, objectName1, objectName2, ...]
```

Conversion: `CDMDataStore.identifierPath(from:primPath:)` bridges between prim paths and identifier paths.

---

## 8. Selection Resolution Heuristics

When a user selects an entity in the viewport or a prim in the scene navigator, RCP resolves through this **ordered heuristic chain**:

### Step 1: Direct Lookup via RuntimeIdentifier (Primary)

```
Entity picked from viewport
    │
    ▼
REEntity._handle (C++ opaque pointer)
    │
    ├─ .runtimeIdentifier? → UUID string
    │     └─ Lookup in entity-to-specification map
    │           └─ → PrimNodeSpecification
    │                 └─ .arguments["sourcePrimPath"] → resolvedPrimPath
    │
    └─ .name → entityName runtime attribute
          └─ Fallback: reconstruct path from parent chain
```

### Step 2: Type-Based Filtering

Once the prim path is resolved, RCP checks if the prim's type maps to an actual entity:

```
typeName = spec.arguments["type"]

if typeName is "Scope"                              → NOT an entity
if typeName contains "material" or "shader"          → NOT an entity
if typeName contains "RealityKit"                    → NOT an entity
if typeName is "Preliminary_Behavior"                → NOT an entity
if typeName is "Preliminary_Trigger"                 → NOT an entity
if typeName is "Preliminary_Action"                  → NOT an entity
if typeName is "RealityKitAudioFile"                 → NOT an entity

otherwise (Xform, Mesh, Camera, Light, etc.)         → ✅ IS an entity
```

### Step 3: TransformOptions Check (Most Precise)

For maximum precision, RCP checks the `TransformOptions` bitmask:

```
if transformOptions == [.excludeTranslation, .excludeRotation, .excludeScale] {
    // ALL transform axes excluded → this prim is flattened into parent
    // Walk up to nearest ancestor with at least one transform axis enabled
}
```

This catches cases that type-based filtering might miss (custom schemas, inherited specifications).

### Step 4: Walk Up to Selectable Ancestor

```swift
func resolveSelection(primPath: String, specifications: [String: AnyNodeSpecification]) -> String? {
    var current = primPath
    while !current.isEmpty {
        guard let spec = specifications[current] else {
            current = parentPath(of: current)
            continue
        }
        
        let type = spec.arguments["type"] as? String ?? ""
        let options = spec.transformOptions ?? [.excludeTranslation, .excludeRotation, .excludeScale]
        
        if isSelectable(typeName: type, options: options) {
            return current  // Found a selectable ancestor
        }
        
        current = parentPath(of: current)
    }
    return nil
}
```

### What Creates an Entity

| USD Prim Type | Entity? | Notes |
|---|---|---|
| `Xform` | ✅ Yes | Direct 1:1 mapping |
| `Mesh` | ✅ Yes | Direct 1:1 |
| `Camera` | ✅ Yes | Direct 1:1 |
| `Light` | ✅ Yes | Direct 1:1 |
| `Sphere`/`Cube`/`Cylinder`/`Cone`/`Capsule` | ✅ Yes | Primitive shapes |
| `Scope` | ❌ No | Pure container; children reparented to parent |
| `Material` (child prim) | ❌ No | Becomes component on parent Xform |
| `Shader` (child prim) | ❌ No | Becomes component on parent Material |
| `RealityKitComponent` | ❌ No | Component on parent entity |
| `Preliminary_Behavior` | ❌ No | Stored in behavior container |
| `Preliminary_Trigger` | ❌ No | Child of behavior prim |
| `Preliminary_Action` | ❌ No | Child of behavior prim |
| `RealityKitAudioFile` | ❌ No | Stored in audio library component |
| `RealityKitDict` | ❌ No | Data storage |
| `RealityKitMeshSortingGroup` | ❌ No | Component parameter |

### What Creates EXTRA Entities (no matching prim)

| Internal Entity | Cause | Prim Equivalent |
|---|---|---|
| `EntityPhysicsContainer` | Physics body + collision | Prim has `Preliminary_PhysicsRigidBodyAPI` schema |
| `CollisionShape` child | Collider geometry | Prim has `Preliminary_PhysicsColliderAPI` schema |
| Audio source entity | Playback entity | Prim has `RealityKitAudioFile` |
| Anonymous root wrapper | `Entity(contentsOf:)` always wraps | No prim (skip it) |
| `usdPrimitiveAxis` | Internal geometry for Cone/Capsule | Not from USD |

### Reference and Payload Handling

When a prim has a reference:

```usda
def Xform "MyAsset" (
    prepend references = @./asset.usda@</Assets/MyModel>
) { }
```

RCP stores both paths:
- `sourcePrimPath` = `/Root/MyAsset` (the referencing prim)
- `referencedPrimPath` = `/Assets/MyModel` (the target in the referenced file)

When selecting a child entity that came from a reference, the resolution maps through the composition arc:
```
Entity selected → runtimeIdentifier → specification lookup
  → sourcePrimPath = "/Assets/MyModel/Child"
  → referencedPrimPath = "/Root/MyAsset → /Assets/MyModel"
  → RESOLVED: "/Root/MyAsset/Child"
```

---

## 9. Key Data Structures

### AFUSDExportContext (confirmed at `0x1e3164`)

```swift
struct AFUSDExportContext {
    var instance: AssetFactoryHolder & HasEntity & NodeSpecification
    var scene: USKScene                          // the USD scene being written to
    var resolver: AssetResolver?                  // defaults to DefaultAssetResolver
    var engineQueue: DispatchQueue?
    var temporaryDirectory: URL
}
```

### AFEvaluatorGenerateContext

```swift
struct AFEvaluatorGenerateContext {
    var urlAccessor: AssetURLAccessor
    var subPath: String
    var withDescendants: Bool
    var includeSceneScaling: Bool
    var dataGeneratorHandler: ((REAsset, URL, AssetDataAccessor) throws -> Void)?
    var generateContext: Any?
}
```

### Overrides

```swift
struct Overrides {
    var factory: AssetFactory?
    var arguments: SortedDictionary<String, ParameterTypeProtocol>
    var runtimeAttributes: ParameterMetadata
    var overrides: [String: OverrideValue]?     // recursive
    var childrenDictionary: [String: Transform?]?
}
```

### HasEntity Protocol

File path from strings: `CoreAsset/HasEntity.swift`

```swift
protocol HasEntity {
    var entity: REEntity? { get }
    // Tags, accessibility, runtime attributes
}
```

### NodeSpecificationProtocol

```swift
protocol NodeSpecificationProtocol {
    var specification: AnyNodeSpecification? { get }
}
```

---

## 10. C Function Imports

The following C functions are imported by CoreAsset (confirmed via stub addresses):

### Entity Management
```
REEntityCreate
REEntityCreateCopy
REEntityAddComponent
REEntityAddExistingComponent
REEntityGetComponent
REEntityGetComponentByClass
REEntityGetOrAddComponentByClass
REEntityRemoveComponent
REEntityRemoveComponentByClass
REEntityGetChildCount
REEntityGetChildren
REEntityGetParent
REEntityGetSceneNullable
REEntityGetName
REEntitySetName
REEntitySetParent
REEntityGetSelfEnabled
REEntitySetSelfEnabled
REEntityRemoveFromSceneOrParent
REEntityComputeLocalBoundingBox
REEntityComputeMeshBoundsAnchoredIncludingInactive
```

### Transform Component
```
RETransformComponentGetComponentType    — Returns the RE component type ID for transforms
RETransformComponentGetLocalPose        — Reads 4x4 pose matrix (position + rotation)
RETransformComponentGetLocalScale       — Reads 4x4 scale matrix
RETransformComponentSetLocalPose        — Writes 4x4 pose matrix
RETransformComponentSetLocalScale       — Writes 4x4 scale matrix
```

### Networking / Dirty Tracking
```
RENetworkMarkComponentDirty — Marks entity as needing sync to engine
```

---

## 11. Warning/Error Strings

Confirmed at their respective addresses in the CoreAsset binary:

| Address | String | Context |
|---------|--------|---------|
| `0x2e0c30` | `"xformOp:translate"` | USD xformOp property name (export) |
| `0x2e0c50` | `"Could not find USKNode at path: "` | Node lookup failure |
| `0x2e0c80` | `"Could not load the USKScene from "` | Scene load failure |
| `0x2e0cb0` | `"Could not find a USKProperty named "` | Property lookup failure |
| `0x2e0ce0` | `"Could not create a USKProperty named "` | Property creation failure |
| `0x2e0d10` | `"Invalid node path: "` | Bad object path |
| `0x2e0d30` | `"Could not create USKNode of type "` | Node creation failure |
| `0x2e3310` | `"Warning: trying to set a non-decomposable matrix to RE Entity. This transform will be ignored."` | Matrix decomposition failure |
| `0x2e42c0` | `"Warning: non-decomposable matrices are not supported. That transform will be ignored."` | Same warning, different code path |
| `0x2fc60` | `"Unable to read scale value from USD due to error: [%@]. Defaulting to [%f]"` | Scale read fallback |
| `0x2e23c0` | `"includeSceneScaling"` | Parameter key |
| `0x2e0920` | `"Validation failed with unsupported file version: %d for url: %@"` | Version check |
| `0x2e0960` | `"Validation failed with not enough memory for url: %@"` | Memory check |
| `0x2e09a0` | `"Unsupported url: %@ error: %@"` | URL validation |
| `0x2e09c0` | `"Cannot read data in url: %@ error: %@"` | Data read failure |
| `0x2e2480` | `"translate"` | Expression translate op |
| `0x2e3420` | `"rigidBody-enabled"` | Physics rigid body flag |
| `0x2e3440` | `"rigidBody-collisionShape"` | Collision shape reference |
| `0x2e3460` | `"rigidBody-shapeType"` | Shape type (box, sphere, etc.) |
| `0x2e3480` | `"rigidBody-material"` | Physics material reference |
| `0x2e3310` | `"xformOp:translate"` | xformOp property (export) |

Additional error strings from the RCP research (from RealityToolsFoundation):

| Error String | Context |
|---|---|
| `"Requested entity before creation for prim at path"` | Lazy entity creation — `convertToRealityKitEntity()` not yet called |
| `"Prim not found at identifier path:"` | Identifier path lookup failure |
| `"Failed to get EditorObject for identifier path:"` | EditorObject is the canonical editor lookup |
| `"EditorObject identifierPath does not contain sceneID:"` | Malformed identifier path |

---

## 12. Deconstructed Implementation Guidance

### 12.1 Current SceneNode Model

```swift
// Deconstructed/Packages/DeconstructedLibrary/Sources/SceneGraphModels/SceneNode.swift
public struct SceneNode: Identifiable, Sendable, Hashable {
    public let id: String          // = primPath (e.g. "/Root/Cube")
    public let name: String        // prim name
    public let typeName: String?   // e.g. "Xform", "Mesh", "Scope"
    public let specifier: SceneNodeSpecifier  // def, over, class
    public let path: String        // full USD prim path
    public var children: [SceneNode]
}
```

The scene graph is loaded via `SceneGraphClient` (at `SceneGraphClients/SceneGraphClient.swift`), which calls `USDInteropStage.sceneGraphJSON(url:)` to get the C++-side node tree as JSON, then decodes it into `SceneNode` values.

### 12.2 Current Selection Flow

```
SceneNavigator (prim tree)                StageView (entity tree)
   │                                            │
   │  SceneNode.id = primPath                   │  entityPicked returns entity path
   │  (e.g. "/Root/Cube")                       │  (format depends on StageView)
   ▼                                            ▼
DocumentEditorFeature
   │
   ├─ .selectionChanged(nodeID)
   │    → resolvedInspectableSelectionPath()
   │    → .viewport(.selectionChanged(id))
   │    → .inspector(.selectionChanged(id))
   │
   └─ .entityPicked(path)
        → resolvedInspectableSelectionPath()
        → .sceneNavigator(.selectionChanged(resolvedPath))
        → .inspector(.selectionChanged(resolvedPath))
```

### 12.3 Current Remapping (the `resolvedInspectableSelectionPath`)

```swift
// Only handles Material and Shader by walking up to parent
private func resolvedInspectableSelectionPath(
    _ path: String?, nodes: [SceneNode]
) -> String? {
    guard let path, let node = findSceneNode(id: path, in: nodes) else { return path }
    let type = node.typeName?.lowercased() ?? ""
    guard type.contains("material") || type.contains("shader") else { return path }
    
    var currentPath = path
    while true {
        let components = currentPath.split(separator: "/")
        guard components.count > 1 else { return path }
        currentPath = "/" + components.dropLast().joined(separator: "/")
        guard let ancestor = findSceneNode(id: currentPath, in: nodes) else { continue }
        let ancestorType = ancestor.typeName?.lowercased() ?? ""
        if !(ancestorType.contains("material") || ancestorType.contains("shader")) {
            return ancestor.path
        }
    }
}
```

### 12.4 Recommended Improvements

Based on the CoreAsset decompilation, the remapping should be extended:

```swift
// Heuristic 1: Complete list of non-entity prim types
func isSelectablePrim(typeName: String?) -> Bool {
    guard let typeName else { return true }
    let lower = typeName.lowercased()
    
    if lower == "scope" { return false }
    if lower.contains("material") || lower.contains("shader") { return false }
    if lower.contains("realitykit") { return false }
    if lower.hasPrefix("preliminary_") { return false }
    if lower == "realitykitaudiofile" { return false }
    
    return true
}

// Heuristic 2: Complete remapping
func resolveSelection(primPath: String?, nodes: [SceneNode]) -> String? {
    guard let path = primPath else { return nil }
    
    // Find the node
    guard let node = findNode(id: path, in: nodes) else {
        // Not in scene tree — this could be an extra entity (physics container)
        // or a renamed entity. Try walking up.
        return path
    }
    
    // Check if it's selectable
    if isSelectablePrim(typeName: node.typeName) {
        return path
    }
    
    // Walk up to nearest selectable ancestor
    var current = path
    while true {
        let components = current.split(separator: "/")
        guard components.count > 1 else { return path }
        current = "/" + components.dropLast().joined(separator: "/")
        guard let ancestor = findNode(id: current, in: nodes) else { continue }
        if isSelectablePrim(typeName: ancestor.typeName) {
            return ancestor.path
        }
    }
}
```

### 12.5 Stability Strategy

The ideal approach matching RCP's stability:

| Level | Mechanism | Implementation |
|---|---|---|
| **1 — Persistent** | UUID on each entity | Add a `PrimPathComponent` custom component with UUID + prim path. Store UUID ↔ primPath mapping in state. |
| **2 — Structural** | Hierarchy walk | Entity tree mirrors prim tree. Walk by name with `_N` suffix handling. |
| **3 — Type-based** | Walk-up remapping | For non-selectable types (Scope, Material, Component), walk up. |
| **4 — Fallback** | Best-effort path match | Match by leaf name uniqueness, fall back to ancestor chains. |

### 12.6 Material Binding Verification

Confirmed from RCP reference project that material bindings are authored as standard USD relationships:

```usda
rel material:binding = </Root/Cube/DefaultMaterial>
```

This is NOT stored in `.realitycomposerpro` metadata — it's authored directly in the USDA file.

### 12.7 CI-Safe Dependency Management

- No `.package(path:)` committed in `Package.swift`
- No `XCLocalSwiftPackageReference` committed in `.pbxproj`
- Local packages handled via workspace (not project)
- SwiftPM mirrors for local development (`Scripts/spm-mirrors/`)

---

## 13. Appendix: Address Reference

### CoreAsset Binary Addresses

| Symbol | Address |
|---|---|
| **USKScene** | |
| `USKScene.load(from:)` | `0x34634` |
| `USKScene.addNode(name:parent:type:)` | `0x32138` |
| `USKScene.addNode(path:type:)` | `0x34878` |
| `USKScene.getOrAddNode(name:parent:type:)` | `0x3498c` |
| `USKScene.findNode(path:)` | `0x34fd4` |
| `USKScene.newChildName(prefix:parentPath:)` | `0x34c3c` |
| `USKScene.metersPerUnit` | `0x34590` |
| `USKScene.timeCodesPerSecond` | `0x34504` |
| `USKScene.MetadataKeys.metersPerUnit` | `0x33db4` |
| `USKScene.MetadataKeys.upAxis` | `0x3446c` |
| `USKScene.MetadataKeys.defaultPrim` | `0x3448c` |
| `USKScene.MetadataKeys.timeCodesPerSecond` | `0x344b8` |
| `USKScene.MetadataKeys.autoPlay` | `0x344e0` |
| `USKScene.makeTexturesCompatibleWithUSDZ` | `0x1579d0` |
| `USKScene.remapTexturesIfInUSDZ` | `0x15804c` |
| `USKScene.addNode(name:prefix:type:)` (variant) | `0x34b48` |
| **USKNode** | |
| `USKNode.set(scale:orientation:translation:)` | `0x3239c` |
| `USKNode.addProperty(name:type:role:)` | `0x322d0` |
| `USKNode.findProperty(name:)` | `0x34084` |
| `USKNode.getMeshBoundingBox()` | `0x32cd8` |
| `USKNode.getExtentsBoundingBox()` | `0x32eb0` |
| `USKNode.getBBox(atTime:except:)` | `0x330a8` |
| `USKNode.hasText` | `0x33db4` |
| **RESceneImportOperation** | |
| `RESceneImportOperation.preFlight()` | `0x15e36c` |
| `RESceneImportOperation.run()` | `0x15e3c0` |
| `RESceneImportOperation.publishToEngine()` | `0x15e50c` |
| `RESceneImportOperation.getSceneAsset()` | `0x15e5d4` |
| `RESceneImportOperation.getSceneHierarchy()` | `0x15e574` |
| `RESceneImportOperation.handles` (getter) | `0x15e0cc` |
| `RESceneImportOperation.init(url:serviceLocator:)` | `0x15e170` |
| `RESceneImportOperation.setMergeIntoSingleEntity(_:)` | `0x15e288` |
| `RESceneImportOperation.setCompressTextures(_:)` | `0x15e26c` |
| **REEntity** | |
| `REEntity.init(OpaquePointer)` | `0x15cb9c` |
| `REEntity.convertToRealityKitEntity()` | `0x15d548` |
| `REEntity.setTransform(Transform)` | `0x15c508` |
| `REEntity.getTransform()` | `0x15d638` |
| `REEntity.getTransformMatrix()` | `0x1623c4` |
| `REEntity.isValid(transform:)` | `0x15ff78` |
| `REEntity.name` (getter) | `0x15d63c` |
| `REEntity.name` (setter) | `0x15c4c0` |
| `REEntity.parent` (getter) | `0x15fb0c` |
| `REEntity.parent` (setter) | `0x15ca40` |
| `REEntity.children` | `0x15c19c` |
| `REEntity.copy(recursive:)` | `0x15fce0` |
| `REEntity.runtimeIdentifier` (getter) | `0x2b88b8` |
| `REEntity.runtimeIdentifier` (setter) | `0x2b88d0` |
| `REEntity.scene` | `0x15f880` |
| `REEntity.mesh` | `0x15c8a4` |
| `REEntity.materials` | `0x15c908` |
| `REEntity.isSelfActive` | `0x160104` |
| **REScene** | |
| `REScene.createEntity()` | `0x15c470` |
| `REScene.allEntities` | `0x15d41c` |
| `REScene.entities` | `0x15d654` |
| `REScene.add(entity:)` | `0x15f7a8` |
| **FileImportBuilderFactory** | |
| `createArguments(url:subPath:includeSceneScaling:withDescendants:)` | `0x142960` |
| `initialSceneTransform(for:with:afContext:)` | `0x143608` |
| `getImportedTransform(for:context:)` | `0x1456ac` |
| `asChildOverrides(url:afContext:childName:)` | `0x1439d8` |
| `getChildrenAsOverrides(for:parentContext:)` | `0x1440b4` |
| `canExpand(for:context:)` | `0x145190` |
| `export(to:with:in:)` | `0x146cc0` |
| **PrimNodeSpecification** | |
| `PrimNodeSpecification.assetPathArgumentKey` | `0x14ce20` |
| `PrimNodeSpecification.sourcePrimPathArgumentKey` | `0x14ceb8` |
| `PrimNodeSpecification.referencedPrimPathArgumentKey` | `0x14ce74` |
| `PrimNodeSpecification.displayNameArgumentKey` | `0x14ce2c` |
| `PrimNodeSpecification.typeArgumentKey` | `0x14ce9c` |
| `PrimNodeSpecification.wantDefaultMaterialKey` | `0x14cee8` |
| `PrimNodeSpecification.transformOverrideExclusionsKey` | `0x14cf10` |
| `PrimNodeSpecification.transformOptions` | `0x14d764` |
| `PrimNodeSpecification.init(transform:arguments:)` | `0x14cf38` |
| `PrimNodeSpecification.encode(to:)` | `0x14d3a8` |
| `PrimNodeSpecification.init(from:)` | `0x14d6cc` |
| **AnyNodeSpecification** | |
| `AnyNodeSpecification.init(assetFactory:arguments:transform:runtimeAttributes:overrides:)` | `0x14e528` |
| `AnyNodeSpecification.setTransform(_:)` | `0x14d9b4` |
| `AnyNodeSpecification.encode(to:)` | `0x14dd5c` |
| `AnyNodeSpecification.init(from:)` | `0x14e1c8` |
| **RuntimeAttributeKeys** | |
| `RuntimeAttributeKeys.RuntimeIdentifier` | `0x197418` |
| `RuntimeAttributeKeys.EntityName` | `0x197100` |
| `RuntimeAttributeKeys.EntityHidden` | `0x1974c0` |
| `RuntimeAttributeKeys.Expressions` | `0x19705c` |
| `RuntimeAttributeKeys.Components` | `0x197578` |
| `RuntimeAttributeKeys.Interactions` | `0x197440` |
| `RuntimeAttributeKeys.Tags` | `0x19746c` |
| `RuntimeAttributeKeys.LockParameters` | `0x1974a4` |
| **Overrides** | |
| `Overrides.setRuntimeAttribute(name:value:)` | `0x1ff7c4` |
| `Overrides.setRuntimeAttribute(name:value:for:)` | `0x1fbde0` |
| `Overrides.recursivelySetRuntimeAttribute(name:value:)` | `0x1ff8c0` |
| `Overrides.recursivelyMapValues(forRuntimeAttributeName:)` | `0x2001cc` |
| **Export** | |
| `Node.recursivelyExport(to:in:preOrder:postOrder:)` | `0x67a70` |
| `ContainerFactory.export(with:to:in:geometryCacheKey:materialCacheKey:)` | `0x17764` |
| `AFUSDExportContext.init(instance:scene:resolver:engineQueue:temporaryDirectory:)` | `0x1e3164` |
| **Strings** | |
| `"sourcePrimPath"` | `0x2d08e0` |
| `"referencedPrimPath"` | `0x2e3040` |
| `"RuntimeIdentifier"` | `0x2e3830` |
| `"xformOp:translate"` | `0x2e0c30` |
| `"transformEnable("` | `0x2e0800` |
| `"usda"` | `0x2e2a8f` |
| `"usdc"` | `0x2e2a8a` |
| `"usdz"` | `0x2e2a85` |
| `"obj"` | `0x2e2a81` |