# Custom Component Type Research

## Goal

Determine the **complete, definitive list** of Swift types that RCP supports in custom components, so Deconstructed's inspector can render appropriate UI widgets for every possible field.

---

## Key Discovery: Fields Are NOT in USD

Custom component field data does **not** appear as USD attributes. The USD file only contains:

```
def RealityKitCustomComponent "ModuleName_ComponentName" (
    active = true
)
{
    uniform token info:id = "ModuleName.ComponentName"
}
```

That's it. No field attributes. The actual field data is serialized somewhere in the Swift/Xcode build pipeline, not in the USD layer.

**Implication**: The type limitation is NOT what OpenUSD can store. It's what RCP's codegen + Xcode validation accepts at Swift compile time.

Evidence: `/Volumes/Plutonian/_Developer/Deconstructed/references/ComponentExploration/Sources/ComponentExploration/ComponentExploration.rkassets/New Component.usda` — the `MyComponent` has one `Int` field but the USD file shows zero attributes beyond `info:id`.

---

## Approach 1: OpenUSD Complete Type System

OpenUSD has a **finite, documented** set of types. Source: [OpenUSD Sdf docs](https://openusd.org/release/api/sdf_page_front.html)

### Scalar Types (13)

| USD Type | C++ Type | Swift Equivalent | Deconstructed Handles |
|----------|----------|-----------------|----------------------|
| `bool` | `bool` | `Bool` | ✅ |
| `int` | `int` | `Int32` | ✅ |
| `int64` | `int64_t` | `Int64` | ❌ |
| `uint` | `unsigned int` | `UInt32` | ✅ |
| `uint64` | `uint64_t` | `UInt64` | ❌ |
| `float` | `float` | `Float` | ✅ |
| `double` | `double` | `Double` | ✅ |
| `half` | `GfHalf` | `Float16` | ❌ |
| `string` | `std::string` | `String` | ✅ |
| `token` | `TfToken` | `String` (interned) | ✅ |
| `asset` | `SdfAssetPath` | `String` (path) | ✅ |
| `uchar` | `unsigned char` | `UInt8` | ❌ |
| `timecode` | `SdfTimeCode` | N/A | ❌ |

### Dimensioned Types (18)

| USD Type | C++ Type | Swift Equivalent | Deconstructed Handles |
|----------|----------|-----------------|----------------------|
| `float2` | `GfVec2f` | `SIMD2<Float>` | ✅ |
| `float3` | `GfVec3f` | `SIMD3<Float>` | ✅ |
| `float4` | `GfVec4f` | `SIMD4<Float>` | ❌ |
| `double2` | `GfVec2d` | `SIMD2<Double>` | ❌ |
| `double3` | `GfVec3d` | `SIMD3<Double>` | ❌ |
| `double4` | `GfVec4d` | `SIMD4<Double>` | ❌ |
| `half2` | `GfVec2h` | `SIMD2<Float16>` | ❌ |
| `half3` | `GfVec3h` | `SIMD3<Float16>` | ❌ |
| `half4` | `GfVec4h` | `SIMD4<Float16>` | ❌ |
| `int2` | `GfVec2i` | `SIMD2<Int32>` | ❌ |
| `int3` | `GfVec3i` | `SIMD3<Int32>` | ❌ |
| `int4` | `GfVec4i` | `SIMD4<Int32>` | ❌ |
| `matrix2d` | `GfMatrix2d` | `simd_double2x2` | ❌ |
| `matrix3d` | `GfMatrix3d` | `simd_double3x3` | ❌ |
| `matrix4d` | `GfMatrix4d` | `simd_double4x4` | ❌ |
| `quatf` | `GfQuatf` | `simd_quatf` | ✅ |
| `quatd` | `GfQuatd` | `simd_quatd` | ❌ |
| `quath` | `GfQuath` | `simd_quath` | ❌ |

### Array Types

Every scalar and dimensioned type can have an `[]` variant. Examples: `int[]`, `float3[]`, `string[]`, `quatf[]`, etc.

Deconstructed currently handles: `string[]`, `token[]`

### Special Types

| USD Type | Description | Deconstructed Handles |
|----------|-------------|----------------------|
| `rel` | Relationship (path reference) | ✅ |
| `dictionary` | `VtDictionary` (key-value map) | ❌ |

### List Operation Types (not relevant for components)

`intlistop`, `stringlistop`, `tokenlistop`, etc. — these are for USD list editing operations, not component data.

---

## Approach 2: Empirical Test Fixture

### How to Test

1. Create a new RCP project
2. Add the test component Swift files below to `Sources/ProjectName/`
3. Build in Xcode — **compile errors = unsupported types**
4. Open in RCP — **which fields appear in the inspector?**
5. For each visible field — **what UI widget does RCP render?**

### What to Observe Per Field

For each field in the inspector, note:
- **Visible?** (Y/N)
- **Widget type**: checkbox, number field, slider, text field, dropdown, color picker, xyz widget, etc.
- **Editable?** (Y/N)
- **Error/warning?** (any red text or badges)

### Test Fixture: ScalarComponent

```swift
import RealityKit

public struct ScalarComponent: Component, Codable {
    public var boolField: Bool = false
    public var int8Field: Int8 = 0
    public var int16Field: Int16 = 0
    public var int32Field: Int32 = 0
    public var int64Field: Int64 = 0
    public var intField: Int = 0
    public var uint8Field: UInt8 = 0
    public var uint16Field: UInt16 = 0
    public var uint32Field: UInt32 = 0
    public var uint64Field: UInt64 = 0
    public var uintField: UInt = 0
    public var floatField: Float = 0
    public var doubleField: Double = 0
    public var stringField: String = ""

    public init() {}
}
```

### Test Fixture: VectorComponent

```swift
import RealityKit

public struct VectorComponent: Component, Codable {
    public var float2Field: SIMD2<Float> = .zero
    public var float3Field: SIMD3<Float> = .zero
    public var float4Field: SIMD4<Float> = .zero
    public var double2Field: SIMD2<Double> = .zero
    public var double3Field: SIMD3<Double> = .zero
    public var double4Field: SIMD4<Double> = .zero
    public var int2Field: SIMD2<Int32> = .zero
    public var int3Field: SIMD3<Int32> = .zero
    public var int4Field: SIMD4<Int32> = .zero

    public init() {}
}
```

### Test Fixture: QuaternionMatrixComponent

```swift
import RealityKit

public struct QuaternionMatrixComponent: Component, Codable {
    public var quatfField: simd_quatf = .init(ix: 0, iy: 0, iz: 0, r: 1)
    public var quatdField: simd_quatd = .init(ix: 0, iy: 0, iz: 0, r: 1)

    public init() {}
}
```

### Test Fixture: ArrayComponent

```swift
import RealityKit

public struct ArrayComponent: Component, Codable {
    public var boolArray: [Bool] = []
    public var intArray: [Int] = []
    public var floatArray: [Float] = []
    public var doubleArray: [Double] = []
    public var stringArray: [String] = []
    public var float3Array: [SIMD3<Float>] = []

    public init() {}
}
```

### Test Fixture: OptionalComponent

```swift
import RealityKit

public struct OptionalComponent: Component, Codable {
    public var optionalBool: Bool? = nil
    public var optionalInt: Int? = nil
    public var optionalFloat: Float? = nil
    public var optionalDouble: Double? = nil
    public var optionalString: String? = nil
    public var optionalFloat3: SIMD3<Float>? = nil

    public init() {}
}
```

### Test Fixture: EnumComponent

```swift
import RealityKit

public enum StringEnum: String, Codable {
    case alpha, beta, gamma
}

public enum IntEnum: Int, Codable {
    case zero = 0, one = 1, two = 2
}

public struct EnumComponent: Component, Codable {
    public var stringEnumField: StringEnum = .alpha
    public var intEnumField: IntEnum = .zero

    public init() {}
}
```

### Test Fixture: EdgeCaseComponent

```swift
import Foundation
import RealityKit

public struct SimpleNested: Codable {
    public var x: Int = 0
    public var y: Float = 0

    public init() {}
}

public struct EdgeCaseComponent: Component, Codable {
    public var urlField: URL? = nil
    public var uuidField: UUID? = nil
    public var dateField: Date? = nil
    public var dataField: Data? = nil
    public var nestedField: SimpleNested? = nil

    public init() {}
}
```

### Test Fixture: MatrixComponent

```swift
import RealityKit

public struct MatrixComponent: Component, Codable {
    public var matrix2x2: simd_double2x2 = .init(diagonal: .zero)
    public var matrix3x3: simd_double3x3 = .init(diagonal: .zero)
    public var matrix4x4: simd_double4x4 = .init(diagonal: .zero)

    public init() {}
}
```

---

## Approach 3: RCP Internal Type Mapping

### Sources to Check

1. **Apple Documentation (DocC)**
   - `maxwell docc-search "custom component types"`
   - `maxwell docc-fetch "realitykit/component"`

2. **WWDC Sessions**
   - WWDC 2023 Session 10273: "Work with Reality Composer Pro content in Xcode"
   - Quote at ~22:31: *"Design-time components are for housing simpler data, such as ints, strings, and SIMD values"*
   - Quote: *"You'll see an error in your Xcode project if you add a property to your custom component that's of a type that Reality Composer Pro won't serialize"*

3. **Xcode Swift Interfaces**
   - RealityKit framework `.swiftinterface` files may reveal type constraints
   - Check `/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks/RealityKit.framework/`

4. **`realitytool` CLI**
   - Apple's `realitytool` generates schema definitions from Swift components
   - May reveal which types it knows how to serialize
   - Command: `realitytool create-schema` (if available)

5. **AppleUSDSchemas (local)**
   - `/Volumes/Plutonian/_Developer/AppleUSDSchemas/Sources/AppleUSDSchemas/UsdInteractive/CustomComponent.swift`
   - Has `SchemaValue` enum with 9 types: `float, double, bool, string, int, token, vector3f, vector3d, asset, unknown`
   - This is a **runtime extraction** set, NOT the authoring set

---

## Deconstructed Current Coverage

File: `Packages/DeconstructedLibrary/Sources/DeconstructedUSDInterop/DeconstructedUSDInterop.swift`
Function: `setComponentParameterWithUSDMutation` (line ~1294)

### Types Currently Handled (13)

| Switch Case | USD Type | Swift Parsing |
|-------------|----------|---------------|
| `"bool"` | `SdfValueTypeName.Bool` | `parseUSDBoolLiteral` |
| `"int"` | `SdfValueTypeName.Int` | `parseUSDIntLiteral` → `Int32` |
| `"uint"` | `SdfValueTypeName.UInt` | `parseUSDUIntLiteral` → `UInt32` |
| `"float"` | `SdfValueTypeName.Float` | `parseUSDFloatLiteral` |
| `"double"` | `SdfValueTypeName.Double` | `parseUSDDoubleLiteral` |
| `"string"` | `SdfValueTypeName.String` | `parseUSDQuotedStringLiteral` |
| `"token"` | `SdfValueTypeName.Token` | `parseUSDQuotedStringLiteral` |
| `"asset"` | `SdfValueTypeName.Asset` | `parseUSDAssetLiteral` |
| `"string[]"` | `SdfValueTypeName.StringArray` | `parseUSDStringArrayLiteral` |
| `"token[]"` | `SdfValueTypeName.TokenArray` | `parseUSDStringArrayLiteral` |
| `"float2"` | `SdfValueTypeName.Float2` | `parseUSDFloatTuple(count: 2)` |
| `"float3"` | `SdfValueTypeName.Float3` | `parseUSDFloatTuple(count: 3)` |
| `"quatf"` | `SdfValueTypeName.Quatf` | `parseUSDFloatTuple(count: 4)` |
| `"rel"` | (relationship) | `parseUSDRelationshipTargetsLiteral` |

### Known Gaps (not yet in Deconstructed)

These OpenUSD types exist but are NOT handled by Deconstructed:
- `int64`, `uint64`, `half`, `uchar`, `timecode`
- `float4`, `double2`, `double3`, `double4`
- `half2`, `half3`, `half4`
- `int2`, `int3`, `int4`
- `quatd`, `quath`
- `matrix2d`, `matrix3d`, `matrix4d`
- Arrays of most types (only `string[]` and `token[]` handled)

---

## Results Matrix (Fill In From Testing)

### ScalarComponent

| Field | Swift Type | Compiles? | In Inspector? | Widget | Editable? |
|-------|-----------|-----------|---------------|--------|-----------|
| `boolField` | `Bool` | | | | |
| `int8Field` | `Int8` | | | | |
| `int16Field` | `Int16` | | | | |
| `int32Field` | `Int32` | | | | |
| `int64Field` | `Int64` | | | | |
| `intField` | `Int` | | | | |
| `uint8Field` | `UInt8` | | | | |
| `uint16Field` | `UInt16` | | | | |
| `uint32Field` | `UInt32` | | | | |
| `uint64Field` | `UInt64` | | | | |
| `uintField` | `UInt` | | | | |
| `floatField` | `Float` | | | | |
| `doubleField` | `Double` | | | | |
| `stringField` | `String` | | | | |

### VectorComponent

| Field | Swift Type | Compiles? | In Inspector? | Widget | Editable? |
|-------|-----------|-----------|---------------|--------|-----------|
| `float2Field` | `SIMD2<Float>` | | | | |
| `float3Field` | `SIMD3<Float>` | | | | |
| `float4Field` | `SIMD4<Float>` | | | | |
| `double2Field` | `SIMD2<Double>` | | | | |
| `double3Field` | `SIMD3<Double>` | | | | |
| `double4Field` | `SIMD4<Double>` | | | | |
| `int2Field` | `SIMD2<Int32>` | | | | |
| `int3Field` | `SIMD3<Int32>` | | | | |
| `int4Field` | `SIMD4<Int32>` | | | | |

### QuaternionMatrixComponent

| Field | Swift Type | Compiles? | In Inspector? | Widget | Editable? |
|-------|-----------|-----------|---------------|--------|-----------|
| `quatfField` | `simd_quatf` | | | | |
| `quatdField` | `simd_quatd` | | | | |

### ArrayComponent

| Field | Swift Type | Compiles? | In Inspector? | Widget | Editable? |
|-------|-----------|-----------|---------------|--------|-----------|
| `boolArray` | `[Bool]` | | | | |
| `intArray` | `[Int]` | | | | |
| `floatArray` | `[Float]` | | | | |
| `doubleArray` | `[Double]` | | | | |
| `stringArray` | `[String]` | | | | |
| `float3Array` | `[SIMD3<Float>]` | | | | |

### OptionalComponent

| Field | Swift Type | Compiles? | In Inspector? | Widget | Editable? |
|-------|-----------|-----------|---------------|--------|-----------|
| `optionalBool` | `Bool?` | | | | |
| `optionalInt` | `Int?` | | | | |
| `optionalFloat` | `Float?` | | | | |
| `optionalDouble` | `Double?` | | | | |
| `optionalString` | `String?` | | | | |
| `optionalFloat3` | `SIMD3<Float>?` | | | | |

### EnumComponent

| Field | Swift Type | Compiles? | In Inspector? | Widget | Editable? |
|-------|-----------|-----------|---------------|--------|-----------|
| `stringEnumField` | `StringEnum` (String-based) | | | | |
| `intEnumField` | `IntEnum` (Int-based) | | | | |

### EdgeCaseComponent

| Field | Swift Type | Compiles? | In Inspector? | Widget | Editable? |
|-------|-----------|-----------|---------------|--------|-----------|
| `urlField` | `URL?` | | | | |
| `uuidField` | `UUID?` | | | | |
| `dateField` | `Date?` | | | | |
| `dataField` | `Data?` | | | | |
| `nestedField` | `SimpleNested?` | | | | |

### MatrixComponent

| Field | Swift Type | Compiles? | In Inspector? | Widget | Editable? |
|-------|-----------|-----------|---------------|--------|-----------|
| `matrix2x2` | `simd_double2x2` | | | | |
| `matrix3x3` | `simd_double3x3` | | | | |
| `matrix4x4` | `simd_double4x4` | | | | |

---

## Reference Files

| Path | Description |
|------|-------------|
| `references/ComponentExploration/Sources/ComponentExploration/MyComponent.swift` | RCP-generated custom component template |
| `references/ComponentExploration/Sources/ComponentExploration/ComponentExploration.rkassets/New Component.usda` | USD with custom component (shows no field attributes) |
| `Packages/DeconstructedLibrary/Sources/DeconstructedUSDInterop/DeconstructedUSDInterop.swift:1294` | Current type handling switch statement |
| `Docs/Inspector-Components-Research-Log.md:288` | Existing research plan |
| `/Volumes/Plutonian/_Developer/AppleUSDSchemas/Sources/AppleUSDSchemas/UsdInteractive/CustomComponent.swift` | SchemaValue enum (runtime extraction types) |

---

## Next Steps After Testing

1. Fill in the Results Matrix above
2. Compare against Deconstructed's current 13 handled types
3. Add missing types to `DeconstructedUSDInterop.swift`
4. Update inspector UI widgets to match RCP's widget choices
5. Document the definitive list in `Inspector-Verified-Field-Matrix.md`
