import RealityKit
import simd

/// ECS system that manages outline child entities for any entity with a
/// ``SelectionOutlineComponent``.
///
/// Register once at app startup:
/// ```swift
/// SelectionOutlineSystem.registerSystem()
/// ```
public final class SelectionOutlineSystem: System {
	private static let outlineEntityName = "__selectionOutline__"
	private static let baseScaleBias: Float = 1.0

	static let query = EntityQuery(where: .has(SelectionOutlineComponent.self))
	static let cameraQuery = EntityQuery(where: .has(PerspectiveCameraComponent.self))

	public required init(scene: Scene) {}

	@MainActor
	public func update(context: SceneUpdateContext) {
		let cameraPosition: SIMD3<Float>? = findCameraWorldPosition(in: context.scene)

		for entity in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
			guard var component = entity.components[SelectionOutlineComponent.self] else {
				continue
			}

			let config = component.configuration

			guard let modelComponent = entity.components[ModelComponent.self] else {
				removeOutlineChild(from: entity, component: &component)
				entity.components.set(component)
				continue
			}

			let outlineEntity: Entity
			if let existingID = component.outlineEntityID,
			   let existing = entity.children.first(where: { $0.id == existingID }) {
				outlineEntity = existing
			} else {
				outlineEntity = Entity()
				outlineEntity.name = Self.outlineEntityName

				do {
					let material = try OutlineMaterial.make(configuration: config)
					let outlineModel = ModelComponent(
						mesh: modelComponent.mesh,
						materials: [material]
					)
					outlineEntity.components.set(outlineModel)
				} catch {
					continue
				}

				entity.addChild(outlineEntity)
				component.outlineEntityID = outlineEntity.id
				entity.components.set(component)
			}

			let noRef: Entity? = nil
			let entityWorldPos = entity.position(relativeTo: noRef)
			let distance: Float
			if let cam = cameraPosition {
				distance = max(0.5, simd_length(cam - entityWorldPos))
			} else {
				distance = config.referenceDistance
			}

			let distanceScale = distance / config.referenceDistance
			let shellScale = Self.baseScaleBias + config.width * distanceScale
			outlineEntity.scale = SIMD3<Float>(repeating: shellScale)

			// Update material if configuration changed (color).
			if let existingModel = outlineEntity.components[ModelComponent.self] {
				do {
					let newMaterial = try OutlineMaterial.make(configuration: config)
					var updatedModel = existingModel
					updatedModel.materials = [newMaterial]
					outlineEntity.components.set(updatedModel)
				} catch {
					// Keep existing material on failure.
				}
			}
		}
	}

	// MARK: - Helpers

	@MainActor
	private func removeOutlineChild(from entity: Entity, component: inout SelectionOutlineComponent) {
		if let id = component.outlineEntityID,
		   let child = entity.children.first(where: { $0.id == id }) {
			child.removeFromParent()
		}
		component.outlineEntityID = nil
	}

	@MainActor
	private func findCameraWorldPosition(in scene: Scene) -> SIMD3<Float>? {
		let noRef: Entity? = nil
		for entity in scene.performQuery(Self.cameraQuery) {
			return entity.position(relativeTo: noRef)
		}
		return nil
	}
}
