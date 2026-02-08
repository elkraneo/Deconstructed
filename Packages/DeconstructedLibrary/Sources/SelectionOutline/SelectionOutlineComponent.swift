import RealityKit

/// Attach this component to an entity to show a selection outline around it.
///
/// The ``SelectionOutlineSystem`` observes entities with this component and
/// manages the child outline entities automatically.
public struct SelectionOutlineComponent: Component, Sendable {
	public var configuration: OutlineConfiguration

	/// Internal reference to the generated outline child entity.
	/// Managed by ``SelectionOutlineSystem``; do not set manually.
	var outlineEntityID: Entity.ID?

	public init(configuration: OutlineConfiguration = .init()) {
		self.configuration = configuration
	}
}
