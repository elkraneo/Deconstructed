import RealityKit
import SwiftUI
import simd
import ViewportModels

/// RealityKit viewport view with arcball camera controls and grid.
public struct ViewportView: View {
    /// Configuration for rendering options
    let configuration: ViewportConfiguration
    
    /// Optional URL to load a model from
    let modelURL: URL?
	let onCameraStateChanged: (([Float]) -> Void)?
    
    // Internal state
    @State private var rootEntity: Entity?
    @State private var cameraState = ArcballCameraState()
    @State private var sceneBounds = SceneBounds()
    @State private var isZUp = false
    
    public init(
        modelURL: URL? = nil,
        configuration: ViewportConfiguration = ViewportConfiguration(),
		onCameraStateChanged: (([Float]) -> Void)? = nil
    ) {
        self.modelURL = modelURL
        self.configuration = configuration
		self.onCameraStateChanged = onCameraStateChanged
    }
    
    public var body: some View {
        RealityView { content in
            let root = makeSceneRoot()
            content.add(root)
            self.rootEntity = root
            
            // Load model if URL provided
            if let url = modelURL {
                Task {
                    await loadModel(from: url)
                }
            }
        } update: { content in
            updateCamera(state: cameraState)
        }
        .arcballCameraControls(
            state: $cameraState,
            sceneBounds: sceneBounds,
            configuration: configuration
        )
		.onChange(of: cameraState) { _, newState in
			onCameraStateChanged?(matrixToArray(newState.transform))
		}
    }
    
    // MARK: - Scene Setup
    
    @MainActor
    private func makeSceneRoot() -> Entity {
        let root = Entity()
        root.name = "SceneRoot"

        // Model Anchor
        let modelAnchor = Entity()
        modelAnchor.name = "ModelAnchor"
        root.addChild(modelAnchor)

        // Lights
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

        // Grid
        if configuration.showGrid {
            let grid = RealityKitGrid.createGridEntity(
                metersPerUnit: configuration.metersPerUnit,
                worldExtent: Double(sceneBounds.maxExtent) * configuration.metersPerUnit,
                isZUp: isZUp
            )
            root.addChild(grid)
        }

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
    
    @MainActor
    private func loadModel(from url: URL) async {
        do {
            let entity = try await Entity(contentsOf: url)
            entity.name = "LoadedModel"

            let anchor = rootEntity?.findEntity(named: "ModelAnchor")
            anchor?.children.first(where: { $0.name == "LoadedModel" })?.removeFromParent()

            if let modelAnchor = anchor {
                modelAnchor.addChild(entity)

                // Update scene bounds
                let bounds = entity.visualBounds(relativeTo: nil)
                sceneBounds = SceneBounds(min: bounds.min, max: bounds.max)

                // Dynamic Camera Framing
                if let camera = rootEntity?.findEntity(named: "MainCamera") {
                    let extents = bounds.extents
                    let center = bounds.center
                    let maxDim = max(extents.x, max(extents.y, extents.z))

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
        } catch {
            print("[ViewportView] Failed to load model: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Camera
    
    @MainActor
    private func updateCamera(state: ArcballCameraState) {
        guard let camera = rootEntity?.findEntity(named: "MainCamera") else { return }
        camera.transform.matrix = state.transform
    }
}

// MARK: - SIMD Extensions

fileprivate extension SIMD4 where Scalar == Float {
    var isFinite: Bool {
        x.isFinite && y.isFinite && z.isFinite && w.isFinite
    }
}

private func matrixToArray(_ matrix: simd_float4x4) -> [Float] {
	let columns = matrix.columns
	return [
		columns.0.x, columns.0.y, columns.0.z, columns.0.w,
		columns.1.x, columns.1.y, columns.1.z, columns.1.w,
		columns.2.x, columns.2.y, columns.2.z, columns.2.w,
		columns.3.x, columns.3.y, columns.3.z, columns.3.w
	]
}
