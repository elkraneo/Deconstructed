import SwiftUI
import simd

/// State for arcball camera controls.
public struct ArcballCameraState: Equatable, Sendable {
    public var focus: SIMD3<Float>
    public var rotation: SIMD3<Float> // Euler angles (Pitch, Yaw, Roll)
    public var distance: Float
    
    public init(focus: SIMD3<Float> = .zero, rotation: SIMD3<Float> = .zero, distance: Float = 5.0) {
        self.focus = focus
        self.rotation = rotation
        self.distance = distance
    }
    
    /// The camera transform matrix for positioning the camera entity.
    public var transform: simd_float4x4 {
        // Compose transform: Translate(focus) * Rotate(yaw, pitch) * Translate(0, 0, distance)
        // This orbits the camera around the focus point.
        
        // Yaw (Y-axis), Pitch (X-axis)
        let rotX = simd_quatf(angle: rotation.x, axis: [1, 0, 0])
        let rotY = simd_quatf(angle: rotation.y, axis: [0, 1, 0])
        let rotationMatrix = simd_float4x4(rotY * rotX)
        
        let translateFocus = simd_float4x4(
            [1, 0, 0, 0],
            [0, 1, 0, 0],
            [0, 0, 1, 0],
            [focus.x, focus.y, focus.z, 1]
        )
        
        let translateDist = simd_float4x4(
            [1, 0, 0, 0],
            [0, 1, 0, 0],
            [0, 0, 1, 0],
            [0, 0, distance, 1]
        )
        
        return translateFocus * rotationMatrix * translateDist
    }

    /// Camera rotation as quaternion (for orientation display).
    public var quaternion: simd_quatf {
        let rotX = simd_quatf(angle: rotation.x, axis: [1, 0, 0])
        let rotY = simd_quatf(angle: rotation.y, axis: [0, 1, 0])
        return rotY * rotX
    }
}
