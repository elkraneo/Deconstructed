import Foundation

/// Configuration for the RealityKit viewport.
public struct ViewportConfiguration: Sendable {
	// MARK: - Grid
	public var showGrid: Bool
	public var showAxes: Bool
	public var metersPerUnit: Double
	public var isZUp: Bool

	// MARK: - Camera
	public var defaultDistance: Float
	public var minDistance: Float
	public var maxDistance: Float?

	// MARK: - Environment
	public var environment: EnvironmentConfiguration

	public init(
		showGrid: Bool = true,
		showAxes: Bool = true,
		metersPerUnit: Double = 1.0,
		isZUp: Bool = false,
		defaultDistance: Float = 5.0,
		minDistance: Float = 0.01,
		maxDistance: Float? = nil,
		environment: EnvironmentConfiguration = EnvironmentConfiguration()
	) {
		self.showGrid = showGrid
		self.showAxes = showAxes
		self.metersPerUnit = metersPerUnit
		self.isZUp = isZUp
		self.defaultDistance = defaultDistance
		self.minDistance = minDistance
		self.maxDistance = maxDistance
		self.environment = environment
	}
}
