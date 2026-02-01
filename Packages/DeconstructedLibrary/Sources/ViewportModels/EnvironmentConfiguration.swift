import Foundation
import simd

/// Configuration for viewport environment lighting.
public struct EnvironmentConfiguration: Equatable, Sendable {
	/// Path to the selected environment HDR file, or nil for default lighting.
	public var environmentPath: String?

	/// Whether to show the environment as a skybox background.
	public var showBackground: Bool

	/// Environment rotation in degrees (0-360).
	public var rotation: Float

	/// Environment exposure in EV (-3 to +3).
	public var exposure: Float

	/// Background color when showBackground is false.
	public var backgroundColor: SIMD4<Float>

	public init(
		environmentPath: String? = nil,
		showBackground: Bool = true,
		rotation: Float = 0,
		exposure: Float = 0,
		backgroundColor: SIMD4<Float> = SIMD4<Float>(0.18, 0.18, 0.18, 1.0)
	) {
		self.environmentPath = environmentPath
		self.showBackground = showBackground
		self.rotation = rotation
		self.exposure = exposure
		self.backgroundColor = backgroundColor
	}

	/// Converts EV exposure to RealityKit's intensityExponent.
	/// RealityKit uses base-2 exponent, so EV maps directly.
	public var realityKitIntensityExponent: Float {
		exposure
	}

	/// Rotation in radians for RealityKit transform.
	public var rotationRadians: Float {
		rotation * .pi / 180.0
	}
}
