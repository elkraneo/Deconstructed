# RCP Custom Component Type Support Matrix

Empirically tested against Reality Composer Pro inspector.

## ScalarComponent

| Field | Swift Type | Supported? |
|-------|-----------|-----------|
| `boolField` | `Bool` | ✅ |
| `int8Field` | `Int8` | ✅ |
| `int16Field` | `Int16` | ✅ |
| `int32Field` | `Int32` | ✅ |
| `int64Field` | `Int64` | ✅ |
| `intField` | `Int` | ✅ |
| `uint8Field` | `UInt8` | ✅ |
| `uint16Field` | `UInt16` | ✅ |
| `uint32Field` | `UInt32` | ✅ |
| `uint64Field` | `UInt64` | ✅ |
| `uintField` | `UInt` | ✅ |
| `floatField` | `Float` | ✅ |
| `doubleField` | `Double` | ✅ |
| `halfField` | `Float16` | ❌ |
| `stringField` | `String` | ✅ |

## VectorComponent

| Field | Swift Type | Supported? |
|-------|-----------|-----------|
| `float2Field` | `SIMD2<Float>` | ✅ |
| `float3Field` | `SIMD3<Float>` | ✅ |
| `float4Field` | `SIMD4<Float>` | ✅ |
| `double2Field` | `SIMD2<Double>` | ✅ |
| `double3Field` | `SIMD3<Double>` | ✅ |
| `double4Field` | `SIMD4<Double>` | ✅ |
| `half2Field` | `SIMD2<Float16>` | ❌ |
| `half3Field` | `SIMD3<Float16>` | ❌ |
| `half4Field` | `SIMD4<Float16>` | ❌ |
| `int2Field` | `SIMD2<Int32>` | ❌ |
| `int3Field` | `SIMD3<Int32>` | ❌ |
| `int4Field` | `SIMD4<Int32>` | ❌ |

## QuaternionMatrixComponent

| Field | Swift Type | Supported? |
|-------|-----------|-----------|
| `quatfField` | `simd_quatf` | ✅ |
| `quatdField` | `simd_quatd` | ✅ |
| `quathField` | `simd_quath` | ❌ |

## ArrayComponent

| Field | Swift Type | Supported? |
|-------|-----------|-----------|
| `boolArray` | `[Bool]` | ❌ |
| `intArray` | `[Int]` | ❌ |
| `floatArray` | `[Float]` | ❌ |
| `doubleArray` | `[Double]` | ❌ |
| `stringArray` | `[String]` | ❌ |
| `float3Array` | `[SIMD3<Float>]` | ❌ |

## EnumComponent

| Field | Swift Type | Supported? |
|-------|-----------|-----------|
| `stringEnumField` | `StringEnum` (String-based) | ✅ |
| `intEnumField` | `IntEnum` (Int-based) | ✅ |

## OptionalComponent

| Field | Swift Type | Supported? | Needs Confirmation |
|-------|-----------|-----------|-------------------|
| `optionalBool` | `Bool?` | ❌ | ⚠️ |
| `optionalInt` | `Int?` | ✅ | ⚠️ |
| `optionalFloat` | `Float?` | ✅ | ⚠️ |
| `optionalDouble` | `Double?` | ❌ | ⚠️ |
| `optionalString` | `String?` | ✅ | ⚠️ |
| `optionalFloat3` | `SIMD3<Float>?` | ✅ | ⚠️ |

## EdgeCaseComponent

Not yet tested.

## MatrixComponent

Not yet tested.

---

## Summary: Supported vs Unsupported

### Supported Types
- All scalar integers: `Bool`, `Int`, `Int8`, `Int16`, `Int32`, `Int64`, `UInt`, `UInt8`, `UInt16`, `UInt32`, `UInt64`
- All scalar floats: `Float`, `Double`
- Scalar string: `String`
- Float vectors: `SIMD2<Float>`, `SIMD3<Float>`, `SIMD4<Float>`
- Double vectors: `SIMD2<Double>`, `SIMD3<Double>`, `SIMD4<Double>`
- Quaternions: `simd_quatf`, `simd_quatd`
- Enums: String-based, Int-based

### Unsupported Types
- Half precision: `Float16`, `SIMD2<Float16>`, `SIMD3<Float16>`, `SIMD4<Float16>`, `simd_quath`
- Integer vectors: `SIMD2<Int32>`, `SIMD3<Int32>`, `SIMD4<Int32>`
- Arrays: all `[T]` types
