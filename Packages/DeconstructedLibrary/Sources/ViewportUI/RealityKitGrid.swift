import RealityKit

/// Dynamic grid with scale awareness for the viewport.
public struct RealityKitGrid {
    private enum Axis {
        case x
        case y
        case z
    }

    @MainActor
    public static func createGridEntity(
        metersPerUnit: Double,
        worldExtent: Double,
        isZUp: Bool
    ) -> Entity {
        let gridRoot = Entity()
        gridRoot.name = "ReferenceGrid"

        let upAxis: Axis = isZUp ? .z : .y
        let planeAxisA: Axis = .x
        let planeAxisB: Axis = isZUp ? .y : .z

        // Position slightly below ground to prevent z-fighting
        gridRoot.position = offsetPosition(upAxis, offset: -0.001)

        let mpu = metersPerUnit > 0 ? metersPerUnit : 0.01
        let oneMeter = Float(1.0 / mpu)  // Scene units per real meter

        // Extend grid based on world size (min 10m, or 1.5x scene)
        let radiusMeters = Float(max(10.0, worldExtent * mpu * 1.5))
        let unitCount = Int(ceil(radiusMeters))
        let axisLen = Float(unitCount) * oneMeter

        // Materials - use gray for all lines (no colored axes)
        let gridMaterial = UnlitMaterial(color: .gray.withAlphaComponent(0.3))

        let lineThickness: Float = 0.002

        // Grid lines along planeAxisA (offset along planeAxisB)
        for i in -unitCount...unitCount {
            let offset = Float(i) * oneMeter

            let entity = Entity()
            entity.components.set(ModelComponent(
                mesh: lineMesh(length: axisLen * 2, thickness: lineThickness, axis: planeAxisA),
                materials: [gridMaterial]
            ))
            entity.position = offsetPosition(planeAxisB, offset: offset)
            gridRoot.addChild(entity)
        }

        // Grid lines along planeAxisB (offset along planeAxisA)
        for i in -unitCount...unitCount {
            let offset = Float(i) * oneMeter

            let entity = Entity()
            entity.components.set(ModelComponent(
                mesh: lineMesh(length: axisLen * 2, thickness: lineThickness, axis: planeAxisB),
                materials: [gridMaterial]
            ))
            entity.position = offsetPosition(planeAxisA, offset: offset)
            gridRoot.addChild(entity)
        }

        return gridRoot
    }

    private static func lineMesh(length: Float, thickness: Float, axis: Axis) -> MeshResource {
        switch axis {
        case .x:
            return MeshResource.generateBox(width: length, height: thickness, depth: thickness)
        case .y:
            return MeshResource.generateBox(width: thickness, height: length, depth: thickness)
        case .z:
            return MeshResource.generateBox(width: thickness, height: thickness, depth: length)
        }
    }

    private static func offsetPosition(_ axis: Axis, offset: Float) -> SIMD3<Float> {
        switch axis {
        case .x:
            return SIMD3<Float>(offset, 0, 0)
        case .y:
            return SIMD3<Float>(0, offset, 0)
        case .z:
            return SIMD3<Float>(0, 0, offset)
        }
    }
}
