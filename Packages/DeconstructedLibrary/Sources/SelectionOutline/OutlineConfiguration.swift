import AppKit
import RealityKit

/// Appearance configuration for entity selection outlines.
public struct OutlineConfiguration: Sendable, Equatable {
	/// Outline color. Defaults to system orange (matching RCP).
	public var color: NSColor

	/// Outline width in model-space units before distance scaling.
	public var width: Float

	/// Reference distance (in meters) at which the outline renders at exactly `width`.
	/// Farther entities get a proportionally thicker extrusion so the outline stays
	/// roughly the same screen-space size.
	public var referenceDistance: Float

	public init(
		color: NSColor = .systemOrange,
		width: Float = 0.004,
		referenceDistance: Float = 2.0
	) {
		self.color = color
		self.width = width
		self.referenceDistance = referenceDistance
	}
}
