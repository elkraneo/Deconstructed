import ComposableArchitecture
import Foundation
import SceneGraphModels
import simd

public enum InspectorTarget: Equatable, Sendable {
	case sceneLayer
	case prim(path: String)
}

public enum SceneUpAxis: String, Equatable, Sendable {
	case y = "Y"
	case z = "Z"
}

public struct SceneLayerData: Equatable, Sendable {
	public var defaultPrim: String?
	public var availablePrims: [String]
	public var metersPerUnit: Double
	public var upAxis: SceneUpAxis

	public init(
		defaultPrim: String? = nil,
		availablePrims: [String] = [],
		metersPerUnit: Double = 1,
		upAxis: SceneUpAxis = .y
	) {
		self.defaultPrim = defaultPrim
		self.availablePrims = availablePrims
		self.metersPerUnit = metersPerUnit
		self.upAxis = upAxis
	}
}

public struct USDTransformData: Equatable, Sendable {
	public var position: SIMD3<Double>
	public var rotationDegrees: SIMD3<Double>
	public var scale: SIMD3<Double>

	public init(
		position: SIMD3<Double> = .zero,
		rotationDegrees: SIMD3<Double> = .zero,
		scale: SIMD3<Double> = SIMD3<Double>(repeating: 1)
	) {
		self.position = position
		self.rotationDegrees = rotationDegrees
		self.scale = scale
	}
}

public struct InspectorAuthoredAttribute: Equatable, Sendable, Identifiable {
	public var id: String { name }
	public var name: String
	public var value: String

	public init(name: String, value: String) {
		self.name = name
		self.value = value
	}
}

public struct ComponentDescendantAttributes: Equatable, Sendable, Identifiable {
	public var id: String { path }
	public var path: String
	public var name: String
	public var authoredAttributes: [InspectorAuthoredAttribute]

	public init(
		path: String,
		name: String,
		authoredAttributes: [InspectorAuthoredAttribute] = []
	) {
		self.path = path
		self.name = name
		self.authoredAttributes = authoredAttributes
	}
}

@Reducer
public struct InspectorFeature {
	@ObservableState
	public struct State: Equatable {
		public var sceneURL: URL?
		public var selectedNodeID: SceneNode.ID?
		public var layerData: SceneLayerData?
		public var sceneNodes: [SceneNode]
		public var componentAuthoredAttributesByPath: [String: [InspectorAuthoredAttribute]]
		public var componentDescendantAttributesByPath: [String: [ComponentDescendantAttributes]]
		public var errorMessage: String?

		public init(
			sceneURL: URL? = nil,
			selectedNodeID: SceneNode.ID? = nil,
			layerData: SceneLayerData? = nil,
			sceneNodes: [SceneNode] = [],
			componentAuthoredAttributesByPath: [String: [InspectorAuthoredAttribute]] = [:],
			componentDescendantAttributesByPath: [String: [ComponentDescendantAttributes]] = [:],
			errorMessage: String? = nil
		) {
			self.sceneURL = sceneURL
			self.selectedNodeID = selectedNodeID
			self.layerData = layerData
			self.sceneNodes = sceneNodes
			self.componentAuthoredAttributesByPath = componentAuthoredAttributesByPath
			self.componentDescendantAttributesByPath = componentDescendantAttributesByPath
			self.errorMessage = errorMessage
		}

		public var currentTarget: InspectorTarget {
			selectedNodeID.map(InspectorTarget.prim(path:)) ?? .sceneLayer
		}

		public var selectedNode: SceneNode? {
			guard let selectedNodeID else { return nil }
			return findNode(id: selectedNodeID, in: sceneNodes)
		}
	}

	public enum Action: Equatable, Sendable {
		case sceneURLChanged(URL?)
		case selectionChanged(SceneNode.ID?)
		case sceneGraphUpdated([SceneNode])
		case primTransformChanged(USDTransformData)
		case setMaterialBindingSucceeded
		case setMaterialBindingStrengthSucceeded
		case primReferencesEditSucceeded
		case setVariantSelectionSucceeded(String?)
		case addComponentSucceeded(String)
		case setComponentActiveSucceeded(componentPath: String, isActive: Bool)
		case deleteComponentSucceeded(componentPath: String)
		case primTransformSaveSucceeded
		case addAudioMixGroupRequested(componentPath: String)
		case assignAudioMixGroupResourceRequested(
			componentPath: String,
			mixGroupPath: String,
			sourceURL: URL
		)
		case setRawComponentAttributeRequested(
			targetPrimPath: String,
			refreshComponentPath: String,
			attributeType: String,
			attributeName: String,
			valueLiteral: String
		)
	}

	public init() {}

	public var body: some ReducerOf<Self> {
		Reduce { state, action in
			switch action {
			case .sceneURLChanged(let url):
				state.sceneURL = url
				if url == nil {
					state.selectedNodeID = nil
					state.sceneNodes = []
					state.layerData = nil
				}
				return .none

			case .selectionChanged(let id):
				state.selectedNodeID = id
				return .none

			case .sceneGraphUpdated(let nodes):
				state.sceneNodes = nodes
				state.layerData = SceneLayerData(availablePrims: flattenPrimPaths(nodes))
				return .none

			case .addAudioMixGroupRequested,
				.assignAudioMixGroupResourceRequested,
				.setRawComponentAttributeRequested:
				state.errorMessage = "Inspector editing requires the SwiftUsdShell runtime adapter."
				return .none

			case .primTransformChanged,
				.setMaterialBindingSucceeded,
				.setMaterialBindingStrengthSucceeded,
				.primReferencesEditSucceeded,
				.setVariantSelectionSucceeded,
				.addComponentSucceeded,
				.setComponentActiveSucceeded,
				.deleteComponentSucceeded,
				.primTransformSaveSucceeded:
				return .none
			}
		}
	}
}

private func findNode(id: SceneNode.ID, in nodes: [SceneNode]) -> SceneNode? {
	for node in nodes {
		if node.id == id { return node }
		if let child = findNode(id: id, in: node.children) { return child }
	}
	return nil
}

private func flattenPrimPaths(_ nodes: [SceneNode]) -> [String] {
	nodes.flatMap { node in
		[node.path] + flattenPrimPaths(node.children)
	}
}
