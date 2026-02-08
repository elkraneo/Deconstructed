import CoreGraphics
import ImageIO
import RealityKit
import SelectionOutline
import SwiftUI
import USDInterfaces
import ViewportModels
import simd

/// Stores the reconstructed USD prim path on each imported entity.
/// Built once after `Entity(contentsOf:)` by walking the entity hierarchy,
/// which is a 1:1 structural mirror of the USD prim tree.
private struct USDPrimPathComponent: Component, Sendable {
	let primPath: String
}

/// Names injected by RealityKit during USD import that don't correspond to prims.
private let realityKitInternalNames: Set<String> = [
	"usdPrimitiveAxis",
]

/// RealityKit viewport view with arcball camera controls and grid.
public struct ViewportView: View {
	/// Configuration for rendering options
	let configuration: ViewportConfiguration

	/// Optional URL to load a model from
	let modelURL: URL?
	let onCameraStateChanged: (([Float]) -> Void)?
	let cameraTransform: [Float]?
	let cameraTransformRequestID: UUID?
	let frameRequestID: UUID?
	/// Triggers reloading the current model URL without rebuilding the whole SwiftUI view.
	/// This is used to refresh after edits while preserving camera state.
	let modelReloadRequestID: UUID?

	/// Selected USD prim path (e.g. "/Root/Capsule") for live transform application.
	let selectedPrimPath: String?
	/// Latest edited transform for the selected prim.
	let livePrimTransform: USDTransformData?
	/// Changes to this value request applying `livePrimTransform` to the selected prim entity.
	let livePrimTransformRequestID: UUID?
	// Internal state
	@State private var rootEntity: Entity?
	@State private var cameraState = ArcballCameraState()
	@State private var sceneBounds = SceneBounds()
	@State private var isZUp = false
	@State private var appliedCameraTransformRequestID: UUID?
	@State private var appliedModelReloadRequestID: UUID?
	@State private var gridEntity: Entity?
	@State private var appliedLivePrimTransformRequestID: UUID?
	@State private var outlinedEntityIDs: Set<Entity.ID> = []

	/// Bidirectional prim path ↔ entity mapping, built once per model load.
	@State private var primPathToEntityID: [String: Entity.ID] = [:]
	@State private var entityIDToPrimPath: [Entity.ID: String] = [:]

	// IBL state
	@State private var iblEntity: Entity?
	@State private var skyboxEntity: Entity?
	@State private var loadedEnvironmentPath: String?

	public init(
		modelURL: URL? = nil,
		configuration: ViewportConfiguration = ViewportConfiguration(),
		onCameraStateChanged: (([Float]) -> Void)? = nil,
		cameraTransform: [Float]? = nil,
		cameraTransformRequestID: UUID? = nil,
		frameRequestID: UUID? = nil,
		modelReloadRequestID: UUID? = nil,
		selectedPrimPath: String? = nil,
		livePrimTransform: USDTransformData? = nil,
		livePrimTransformRequestID: UUID? = nil
	) {
		self.modelURL = modelURL
		self.configuration = configuration
		self.onCameraStateChanged = onCameraStateChanged
		self.cameraTransform = cameraTransform
		self.cameraTransformRequestID = cameraTransformRequestID
		self.frameRequestID = frameRequestID
		self.modelReloadRequestID = modelReloadRequestID
		self.selectedPrimPath = selectedPrimPath
		self.livePrimTransform = livePrimTransform
		self.livePrimTransformRequestID = livePrimTransformRequestID
	}

	public var body: some View {
		RealityView { content in
			let root = makeSceneRoot()
			content.add(root)
			self.rootEntity = root
			self.isZUp = configuration.isZUp

			// Load model if URL provided
			if let url = modelURL {
				Task {
					await loadModel(from: url, behavior: .sceneOpenedOrChanged)
				}
			}

			// Load initial environment if configured
			if let envPath = configuration.environment.environmentPath {
				Task {
					await loadEnvironment(path: envPath)
				}
			}
		} update: { content in
			// Update camera every frame
			updateCamera(state: cameraState)

			// Update IBL rotation every frame for smooth slider response
			updateIBLRotation(configuration.environment.rotation)

			// Update grid visibility
			gridEntity?.isEnabled = configuration.showGrid

			// Update skybox visibility
			skyboxEntity?.isEnabled = configuration.environment.showBackground
		}
		.arcballCameraControls(
			state: $cameraState,
			sceneBounds: sceneBounds,
			configuration: configuration
		)
		.onChange(of: cameraState) { _, newState in
			onCameraStateChanged?(matrixToArray(newState.transform))
		}
		.onChange(of: cameraTransformRequestID) { _, newID in
			_ = applyCameraTransformIfNeeded(requestID: newID)
		}
		.onChange(of: modelURL) { _, newURL in
			guard let url = newURL else { return }
			Task {
				await loadModel(from: url, behavior: .sceneOpenedOrChanged)
			}
		}
		.onChange(of: modelReloadRequestID) { _, newID in
			guard let id = newID else { return }
			guard appliedModelReloadRequestID != id else { return }
			appliedModelReloadRequestID = id

			guard let url = modelURL else { return }
			Task {
				// Reload the model without framing or camera restore.
				await loadModel(from: url, behavior: .reloadPreservingCamera)
			}
		}
		.onChange(of: livePrimTransformRequestID) { _, newID in
			guard let id = newID else { return }
			guard appliedLivePrimTransformRequestID != id else { return }
			appliedLivePrimTransformRequestID = id

			guard let primPath = selectedPrimPath, let transform = livePrimTransform else { return }
			applyLiveTransform(primPath: primPath, transform: transform)
		}
		.onChange(of: frameRequestID) { _, _ in
			frameScene()
		}
		.onChange(of: configuration.environment.environmentPath) { _, newPath in
			Task {
				if let path = newPath {
					await loadEnvironment(path: path)
				} else {
					await clearEnvironment()
				}
			}
		}
		.onChange(of: configuration.environment.exposure) { _, newExposure in
			updateIBLExposure(newExposure)
		}
		.onChange(of: configuration.environment.backgroundColor) { _, _ in
			updateBackgroundColor()
		}
		.onChange(of: selectedPrimPath) { oldPath, newPath in
			updateSelectionOutline(oldPrimPath: oldPath, newPrimPath: newPath)
		}
	}

	// MARK: - Scene Setup

	@MainActor
	private func makeSceneRoot() -> Entity {
		SelectionOutlineSystem.registerSystem()

		isZUp = configuration.isZUp

		let root = Entity()
		root.name = "SceneRoot"

		// Model Anchor
		let modelAnchor = Entity()
		modelAnchor.name = "ModelAnchor"
		root.addChild(modelAnchor)

		// Lights (will be dimmed when IBL is active)
		let light = DirectionalLight()
		light.name = "KeyLight"
		light.light.intensity = 2000
		light.light.color = .white
		light.look(at: .zero, from: [2, 4, 5], relativeTo: nil)
		root.addChild(light)

		let fillLight = DirectionalLight()
		fillLight.name = "FillLight"
		fillLight.light.intensity = 1000
		fillLight.look(at: .zero, from: [-2, 2, -3], relativeTo: nil)
		root.addChild(fillLight)

		// IBL Entity (for ImageBasedLightComponent)
		let ibl = Entity()
		ibl.name = "ImageBasedLight"
		root.addChild(ibl)
		iblEntity = ibl

		// Skybox Entity (inverted sphere for environment background)
		let skybox = Entity()
		skybox.name = "Skybox"
		skybox.isEnabled = false
		root.addChild(skybox)
		skyboxEntity = skybox

		// Grid
		let grid = RealityKitGrid.createGridEntity(
			metersPerUnit: configuration.metersPerUnit,
			worldExtent: Double(sceneBounds.maxExtent)
				* configuration.metersPerUnit,
			isZUp: configuration.isZUp
		)
		grid.isEnabled = configuration.showGrid
		grid.name = "Grid"
		root.addChild(grid)
		gridEntity = grid

		// Camera
		let camera = PerspectiveCamera()
		camera.name = "MainCamera"
		if var component = camera.components[PerspectiveCameraComponent.self] {
			component.near = 0.001
			component.far = 1000.0
			camera.components.set(component)
		}
		camera.position = [0, 1, 2]
		camera.look(at: .zero, from: [0, 1, 2], relativeTo: nil)
		root.addChild(camera)

		return root
	}

	// MARK: - Model Loading

	private enum ModelLoadBehavior: Sendable {
		/// Used when opening a scene or switching to a different scene URL.
		/// Frames the model unless an explicit camera restore is requested.
		case sceneOpenedOrChanged
		/// Used after edits (e.g. transform changes) when we want the viewport to update
		/// without resetting the user's camera.
		case reloadPreservingCamera
	}

	@MainActor
	private func loadModel(from url: URL, behavior: ModelLoadBehavior) async {
		do {
			// Load first, then swap, so we don't show a blank viewport while loading.
			let newEntity = try await Entity(contentsOf: url)
			newEntity.name = "LoadedModel"

			guard let modelAnchor = rootEntity?.findEntity(named: "ModelAnchor") else {
				return
			}

			let oldEntity = modelAnchor.children.first(where: { $0.name == "LoadedModel" })
			modelAnchor.addChild(newEntity)
			oldEntity?.removeFromParent()

			// Build bidirectional prim path ↔ entity mapping from the imported hierarchy.
			buildPrimPathMapping(root: newEntity)

			// Apply selection outline if a prim is already selected.
			if let primPath = selectedPrimPath {
				updateSelectionOutline(oldPrimPath: nil, newPrimPath: primPath)
			}

			// Update scene bounds
			let bounds = newEntity.visualBounds(relativeTo: nil)
			sceneBounds = SceneBounds(min: bounds.min, max: bounds.max)

			switch behavior {
			case .sceneOpenedOrChanged:
				if applyCameraTransformIfNeeded(
					requestID: cameraTransformRequestID,
					focus: bounds.center
				) == false {
					frameScene(bounds: bounds)
				}
			case .reloadPreservingCamera:
				// Intentionally keep the current cameraState. We only update the model.
				break
			}
		} catch {
			print(
				"[ViewportView] Failed to load model: \(error.localizedDescription)"
			)
		}
	}

	// MARK: - Camera

	@MainActor
	private func updateCamera(state: ArcballCameraState) {
		guard let camera = rootEntity?.findEntity(named: "MainCamera") else {
			return
		}
		camera.transform.matrix = state.transform
	}

	// MARK: - Live USD -> RealityKit Transform

	@MainActor
	private func applyLiveTransform(primPath: String, transform: USDTransformData) {
		guard let entity = resolveEntity(forPrimPath: primPath) else {
			// Best-effort: live updates are optional, the USD file still gets authored.
			return
		}

		let metersPerUnit = configuration.metersPerUnit > 0 ? configuration.metersPerUnit : 1.0

		// USD translate values are in stage units; RealityKit uses meters.
		let translation = SIMD3<Float>(
			Float(transform.position.x * metersPerUnit),
			Float(transform.position.y * metersPerUnit),
			Float(transform.position.z * metersPerUnit)
		)

		let rotation = eulerDegreesXYZToQuat(
			x: Float(transform.rotationDegrees.x),
			y: Float(transform.rotationDegrees.y),
			z: Float(transform.rotationDegrees.z)
		)

		let scale = SIMD3<Float>(
			Float(transform.scale.x),
			Float(transform.scale.y),
			Float(transform.scale.z)
		)

		entity.transform = Transform(scale: scale, rotation: rotation, translation: translation)
	}

	@MainActor
	// MARK: - Prim Path ↔ Entity Mapping

	/// Resolve a USD prim path to its RealityKit entity via the cached mapping.
	private func resolveEntity(forPrimPath primPath: String) -> Entity? {
		guard let root = rootEntity else { return nil }
		guard let entityID = primPathToEntityID[primPath] else { return nil }
		return findEntity(byID: entityID, in: root)
	}

	/// Build bidirectional prim path ↔ entity mappings by walking the imported entity tree.
	///
	/// Entity(contentsOf:) produces a hierarchy that is a 1:1 structural mirror of
	/// the USD prim tree. The anonymous root wrapper (empty name) is not a prim.
	/// RealityKit appends `_N` suffixes for sibling name collisions.
	@MainActor
	private func buildPrimPathMapping(root: Entity) {
		var pathToID: [String: Entity.ID] = [:]
		var idToPath: [Entity.ID: String] = [:]

		func walk(_ entity: Entity, parentPrimPath: String) {
			// Skip the outline system's child entities.
			guard entity.name != SelectionOutlineSystem.outlineEntityName else { return }
			// Skip RealityKit-injected internal entities (e.g. usdPrimitiveAxis).
			guard !realityKitInternalNames.contains(entity.name) else { return }

			let primPath: String
			if entity.name.isEmpty {
				// Anonymous root wrapper — not a USD prim, just pass through.
				primPath = parentPrimPath
			} else {
				// Entity name = prim name. RealityKit may suffix with _N for duplicates.
				// Strip the _N suffix to recover the original prim name.
				let primName = stripDuplicateSuffix(entity.name, amongSiblingsOf: entity)
				primPath = parentPrimPath == "/" ? "/\(primName)" : "\(parentPrimPath)/\(primName)"
			}

			if !entity.name.isEmpty {
				pathToID[primPath] = entity.id
				idToPath[entity.id] = primPath
				entity.components.set(USDPrimPathComponent(primPath: primPath))
			}

			for child in entity.children {
				walk(child, parentPrimPath: primPath)
			}
		}

		// The loaded entity has name = "LoadedModel" (we renamed it).
		// Its children are the USD root prims.
		for child in root.children {
			walk(child, parentPrimPath: "")
		}

		primPathToEntityID = pathToID
		entityIDToPrimPath = idToPath
	}

	/// Strip RealityKit's `_N` duplicate suffix if it was added for sibling collisions.
	///
	/// RealityKit appends `_1`, `_2`, etc. when multiple sibling prims share a name.
	/// We detect this by checking if other siblings share the base name.
	@MainActor
	private func stripDuplicateSuffix(_ name: String, amongSiblingsOf entity: Entity) -> String {
		// Quick check: does the name end with _N pattern?
		guard let lastUnderscore = name.lastIndex(of: "_") else { return name }
		let suffixStart = name.index(after: lastUnderscore)
		guard suffixStart < name.endIndex,
		      name[suffixStart...].allSatisfy(\.isNumber) else { return name }

		let baseName = String(name[..<lastUnderscore])

		// Only strip if a sibling has the same base name (confirming it's a RealityKit suffix).
		guard let parent = entity.parent else { return name }
		let hasSiblingWithBaseName = parent.children.contains { sibling in
			sibling.id != entity.id && (sibling.name == baseName || sibling.name.hasPrefix(baseName + "_"))
		}

		return hasSiblingWithBaseName ? baseName : name
	}

	@MainActor
	private func findEntity(byID id: Entity.ID, in root: Entity) -> Entity? {
		if root.id == id { return root }
		for child in root.children {
			if let found = findEntity(byID: id, in: child) { return found }
		}
		return nil
	}

	private func eulerDegreesXYZToQuat(x: Float, y: Float, z: Float) -> simd_quatf {
		let rx = simd_quatf(angle: x * .pi / 180.0, axis: SIMD3<Float>(1, 0, 0))
		let ry = simd_quatf(angle: y * .pi / 180.0, axis: SIMD3<Float>(0, 1, 0))
		let rz = simd_quatf(angle: z * .pi / 180.0, axis: SIMD3<Float>(0, 0, 1))
		// XYZ order (apply X, then Y, then Z).
		return rz * ry * rx
	}

	// MARK: - Selection Outline

	@MainActor
	private func updateSelectionOutline(oldPrimPath: String?, newPrimPath: String?) {
		// Remove outlines from previously selected entities.
		// Must remove both the component AND the outline child entity directly,
		// because once the component is removed the System no longer sees the entity
		// and cannot clean up its children.
		if !outlinedEntityIDs.isEmpty, let root = rootEntity {
			func removeOutlines(from entity: Entity) {
				if outlinedEntityIDs.contains(entity.id) {
					entity.components.remove(SelectionOutlineComponent.self)
					// Directly remove orphaned outline children.
					let outlineChildren = entity.children.filter {
						$0.name == "__selectionOutline__"
					}
					for child in outlineChildren {
						child.removeFromParent()
					}
				}
				for child in entity.children {
					removeOutlines(from: child)
				}
			}
			removeOutlines(from: root)
			outlinedEntityIDs = []
		}

		// Add outline to newly selected entity (and its mesh descendants).
		guard let primPath = newPrimPath else { return }
		guard let entity = resolveEntity(forPrimPath: primPath) else { return }

		let config = OutlineConfiguration(color: .systemOrange, width: 0.05)

		// Walk all descendants for Xform/reference entities (e.g. USDZ).
		func applyOutline(to target: Entity) {
			// Skip outline children from previous selections.
			guard target.name != "__selectionOutline__" else { return }
			if target.components[ModelComponent.self] != nil {
				target.components.set(SelectionOutlineComponent(configuration: config))
				outlinedEntityIDs.insert(target.id)
			}
			for child in target.children {
				applyOutline(to: child)
			}
		}

		applyOutline(to: entity)
	}

	// MARK: - Environment / IBL

	@MainActor
	private func loadEnvironment(path: String) async {
		guard let ibl = iblEntity,
		      let root = rootEntity else {
			return
		}

		// Skip if already loaded
		if loadedEnvironmentPath == path { return }

		let url = URL(fileURLWithPath: path)
		guard let cgImage = loadHDRImage(from: url) else {
			print("[ViewportView] Failed to load HDR image: \(path)")
			return
		}

		do {
			let resource = try await EnvironmentResource(
				equirectangular: cgImage,
				withName: url.lastPathComponent
			)

			var iblComp = ImageBasedLightComponent(source: .single(resource))
			iblComp.intensityExponent = configuration.environment.realityKitIntensityExponent
			iblComp.inheritsRotation = true
			ibl.components.set(iblComp)

			// Apply IBL rotation
			updateIBLRotation(configuration.environment.rotation)

			// Apply IBL receiver to model hierarchy
			if let modelAnchor = root.findEntity(named: "ModelAnchor") {
				applyIBLReceiver(to: modelAnchor, iblEntity: ibl)
			}

			// Update directional lights (dim when IBL active)
			updateDirectionalLights(useIBL: true)

			// Create skybox if showing background
			await updateSkybox(path: path)

			loadedEnvironmentPath = path
			print("[ViewportView] Loaded environment: \(EnvironmentMaps.displayName(for: path))")
		} catch {
			print("[ViewportView] Failed to create environment resource: \(error)")
		}
	}

	@MainActor
	private func clearEnvironment() async {
		iblEntity?.components.remove(ImageBasedLightComponent.self)
		skyboxEntity?.components.remove(ModelComponent.self)
		skyboxEntity?.isEnabled = false
		updateDirectionalLights(useIBL: false)
		loadedEnvironmentPath = nil
	}

	@MainActor
	private func updateSkybox(path: String) async {
		guard let skybox = skyboxEntity else { return }

		// Use reference HDR for skybox if available, otherwise use IBL
		let skyboxPath = EnvironmentMaps.referencePath(for: path) ?? path
		let url = URL(fileURLWithPath: skyboxPath)

		do {
			let texture = try await TextureResource(contentsOf: url)
			var material = UnlitMaterial()
			material.color = .init(texture: .init(texture))

			// Large inverted sphere for skybox
			let radius: Float = 500.0
			let mesh = MeshResource.generateSphere(radius: radius)
			skybox.components.set(ModelComponent(mesh: mesh, materials: [material]))
			skybox.scale = SIMD3<Float>(-1, 1, 1)  // Invert for interior view
			skybox.isEnabled = configuration.environment.showBackground
		} catch {
			print("[ViewportView] Failed to create skybox: \(error)")
		}
	}

	@MainActor
	private func updateIBLExposure(_ exposure: Float) {
		guard let ibl = iblEntity,
		      var iblComp = ibl.components[ImageBasedLightComponent.self] else {
			return
		}
		iblComp.intensityExponent = exposure
		ibl.components.set(iblComp)
	}

	@MainActor
	private func updateIBLRotation(_ degrees: Float) {
		guard let ibl = iblEntity else { return }

		let radians = degrees * .pi / 180.0
		// Y-up rotation
		let rotation = simd_quatf(angle: radians, axis: SIMD3<Float>(0, 1, 0))
		ibl.transform.rotation = rotation

		// Also rotate skybox
		skyboxEntity?.transform.rotation = rotation
	}

	@MainActor
	private func updateDirectionalLights(useIBL: Bool) {
		guard let root = rootEntity else { return }

		if let keyLight = root.findEntity(named: "KeyLight") as? DirectionalLight {
			keyLight.light.intensity = useIBL ? 0 : 2000
		}
		if let fillLight = root.findEntity(named: "FillLight") as? DirectionalLight {
			fillLight.light.intensity = useIBL ? 0 : 1000
		}
	}

	@MainActor
	private func updateBackgroundColor() {
		// Background color is handled by RealityView's background
		// For now, we toggle skybox visibility
		skyboxEntity?.isEnabled = configuration.environment.showBackground
	}

	private func applyIBLReceiver(to entity: Entity, iblEntity: Entity) {
		entity.components.set(ImageBasedLightReceiverComponent(imageBasedLight: iblEntity))
		for child in entity.children {
			applyIBLReceiver(to: child, iblEntity: iblEntity)
		}
	}

	private func loadHDRImage(from url: URL) -> CGImage? {
		let options: [String: Any] = [
			kCGImageSourceShouldAllowFloat as String: true,
			kCGImageSourceShouldCache as String: false,
		]
		guard let source = CGImageSourceCreateWithURL(url as CFURL, options as CFDictionary),
		      let image = CGImageSourceCreateImageAtIndex(source, 0, options as CFDictionary) else {
			return nil
		}
		return image
	}
}

private extension ViewportView {
	@MainActor
	func applyCameraTransformIfNeeded(
		requestID: UUID?,
		focus: SIMD3<Float>? = nil
	) -> Bool {
		guard let requestID,
		      appliedCameraTransformRequestID != requestID,
		      let cameraTransform,
		      let matrix = matrixFromArray(cameraTransform) else {
			return false
		}
		let focusPoint = focus ?? sceneBounds.center
		guard let restoredState = cameraStateFromTransform(matrix, focus: focusPoint) else {
			return false
		}
		cameraState = restoredState
		appliedCameraTransformRequestID = requestID
		return true
	}

	@MainActor
	func frameScene(bounds: BoundingBox? = nil) {
		let bounds = bounds ?? BoundingBox(min: sceneBounds.min, max: sceneBounds.max)
		frameScene(bounds: bounds)
	}

	@MainActor
	func frameScene(bounds: BoundingBox) {
		let extents = bounds.extents
		let center = bounds.center
		let maxDim = max(extents.x, max(extents.y, extents.z))
		guard maxDim > 0 else { return }

		let fov: Float = 60.0 * .pi / 180.0
		let tanFov = tan(fov / 2.0)
		let distance = maxDim / (2.0 * tanFov)
		let clampedDistance = max(distance, 0.05)

		var newState = ArcballCameraState()
		newState.focus = center
		newState.distance = clampedDistance * 1.5
		newState.rotation = SIMD3<Float>(-20 * .pi / 180, 0, 0)
		cameraState = newState
	}
}

// MARK: - SIMD Extensions

extension SIMD4 where Scalar == Float {
	fileprivate var isFinite: Bool {
		x.isFinite && y.isFinite && z.isFinite && w.isFinite
	}
}

private func matrixToArray(_ matrix: simd_float4x4) -> [Float] {
	let columns = matrix.columns
	return [
		columns.0.x, columns.0.y, columns.0.z, columns.0.w,
		columns.1.x, columns.1.y, columns.1.z, columns.1.w,
		columns.2.x, columns.2.y, columns.2.z, columns.2.w,
		columns.3.x, columns.3.y, columns.3.z, columns.3.w,
	]
}

private func matrixFromArray(_ values: [Float]) -> simd_float4x4? {
	guard values.count == 16 else { return nil }
	return simd_float4x4(
		SIMD4(values[0], values[1], values[2], values[3]),
		SIMD4(values[4], values[5], values[6], values[7]),
		SIMD4(values[8], values[9], values[10], values[11]),
		SIMD4(values[12], values[13], values[14], values[15])
	)
}

private func cameraStateFromTransform(
	_ transform: simd_float4x4,
	focus: SIMD3<Float>
) -> ArcballCameraState? {
	let rotation = simd_float3x3(
		SIMD3(transform.columns.0.x, transform.columns.0.y, transform.columns.0.z),
		SIMD3(transform.columns.1.x, transform.columns.1.y, transform.columns.1.z),
		SIMD3(transform.columns.2.x, transform.columns.2.y, transform.columns.2.z)
	)
	let forward = SIMD3<Float>(
		rotation.columns.2.x,
		rotation.columns.2.y,
		rotation.columns.2.z
	)
	let normalizedForward =
		simd_length(forward) > 0 ? simd_normalize(forward) : SIMD3<Float>(0, 0, 1)
	let clampedY = max(-1.0 as Float, min(1.0 as Float, normalizedForward.y))
	let pitch = -asinf(clampedY)
	let yaw = atan2f(normalizedForward.x, normalizedForward.z)

	let cameraPosition = SIMD3<Float>(
		transform.columns.3.x,
		transform.columns.3.y,
		transform.columns.3.z
	)
	let distance = max(0.001, simd_length(cameraPosition - focus))

	var state = ArcballCameraState()
	state.focus = focus
	state.rotation = SIMD3<Float>(pitch, yaw, 0)
	state.distance = distance
	return state
}
