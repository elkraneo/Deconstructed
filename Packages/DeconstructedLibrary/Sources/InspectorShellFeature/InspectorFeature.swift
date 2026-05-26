import ComposableArchitecture
import Foundation
import SceneGraphModels
import SwiftUsdShell
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
		public var primTransform: SwiftUsdShell.USDTransformData?
		public var materialBinding: SwiftUsdShell.USDMaterialBindingInfo?
		public var primReferences: [SwiftUsdShell.USDReference]
		public var primVariantSets: [SwiftUsdShell.USDVariantSetSummary]
		public var componentAuthoredAttributesByPath: [String: [InspectorAuthoredAttribute]]
		public var componentDescendantAttributesByPath: [String: [ComponentDescendantAttributes]]
		public var errorMessage: String?

		public init(
			sceneURL: URL? = nil,
			selectedNodeID: SceneNode.ID? = nil,
			layerData: SceneLayerData? = nil,
			sceneNodes: [SceneNode] = [],
			primTransform: SwiftUsdShell.USDTransformData? = nil,
			materialBinding: SwiftUsdShell.USDMaterialBindingInfo? = nil,
			primReferences: [SwiftUsdShell.USDReference] = [],
			primVariantSets: [SwiftUsdShell.USDVariantSetSummary] = [],
			componentAuthoredAttributesByPath: [String: [InspectorAuthoredAttribute]] = [:],
			componentDescendantAttributesByPath: [String: [ComponentDescendantAttributes]] = [:],
			errorMessage: String? = nil
		) {
			self.sceneURL = sceneURL
			self.selectedNodeID = selectedNodeID
			self.layerData = layerData
			self.sceneNodes = sceneNodes
			self.primTransform = primTransform
			self.materialBinding = materialBinding
			self.primReferences = primReferences
			self.primVariantSets = primVariantSets
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
		case loadSceneMetadataRequested(URL)
		case sceneMetadataLoaded(SwiftUsdShell.USDStageMetadata)
		case loadPrimTransformRequested(URL, primPath: String)
		case primTransformLoaded(SwiftUsdShell.USDTransformData?)
		case loadMaterialBindingRequested(URL, primPath: String)
		case materialBindingLoaded(SwiftUsdShell.USDMaterialBindingInfo?)
		case loadPrimReferencesRequested(URL, primPath: String)
		case primReferencesLoaded([SwiftUsdShell.USDReference])
		case loadPrimVariantSetsRequested(URL, primPath: String)
		case primVariantSetsLoaded([SwiftUsdShell.USDVariantSetSummary])
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

	@Dependency(\.sceneInspector) var sceneInspector

	public var body: some ReducerOf<Self> {
		Reduce { state, action in
			switch action {
			case .sceneURLChanged(let url):
				state.sceneURL = url
				if let url {
					return .send(.loadSceneMetadataRequested(url))
				}
				state.selectedNodeID = nil
				state.sceneNodes = []
				state.layerData = nil
				state.primTransform = nil
				state.materialBinding = nil
				state.primReferences = []
				state.primVariantSets = []
				return .none

			case .selectionChanged(let id):
				state.selectedNodeID = id
				state.primTransform = nil
				state.materialBinding = nil
				state.primReferences = []
				state.primVariantSets = []
				guard let id, let url = state.sceneURL else {
					return .none
				}
				return .merge(
					.send(.loadPrimTransformRequested(url, primPath: id)),
					.send(.loadMaterialBindingRequested(url, primPath: id)),
					.send(.loadPrimReferencesRequested(url, primPath: id)),
					.send(.loadPrimVariantSetsRequested(url, primPath: id))
				)

			case .loadPrimTransformRequested(let url, let primPath):
				return .run { [sceneInspector] send in
					let transform = await sceneInspector.primTransform(url, primPath)
					await send(.primTransformLoaded(transform))
				}

			case .primTransformLoaded(let transform):
				state.primTransform = transform
				return .none

			case .loadMaterialBindingRequested(let url, let primPath):
				return .run { [sceneInspector] send in
					let info = await sceneInspector.materialBinding(url, primPath)
					await send(.materialBindingLoaded(info))
				}

			case .materialBindingLoaded(let info):
				state.materialBinding = info
				return .none

			case .loadPrimReferencesRequested(let url, let primPath):
				return .run { [sceneInspector] send in
					let refs = await sceneInspector.primReferences(url, primPath)
					await send(.primReferencesLoaded(refs))
				}

			case .primReferencesLoaded(let refs):
				state.primReferences = refs
				return .none

			case .loadPrimVariantSetsRequested(let url, let primPath):
				return .run { [sceneInspector] send in
					let sets = await sceneInspector.primVariantSets(url, primPath)
					await send(.primVariantSetsLoaded(sets))
				}

			case .primVariantSetsLoaded(let sets):
				state.primVariantSets = sets
				return .none

			case .sceneGraphUpdated(let nodes):
				state.sceneNodes = nodes
				let existing = state.layerData ?? SceneLayerData()
				state.layerData = SceneLayerData(
					defaultPrim: existing.defaultPrim,
					availablePrims: flattenPrimPaths(nodes),
					metersPerUnit: existing.metersPerUnit,
					upAxis: existing.upAxis
				)
				return .none

			case .loadSceneMetadataRequested(let url):
				return .run { [sceneInspector] send in
					let metadata = await sceneInspector.stageMetadata(url)
					await send(.sceneMetadataLoaded(metadata))
				}

			case .sceneMetadataLoaded(let metadata):
				let previous = state.layerData ?? SceneLayerData()
				let upAxis = SceneUpAxis(rawValue: metadata.upAxis?.rawValue ?? "Y") ?? .y
				state.layerData = SceneLayerData(
					defaultPrim: metadata.defaultPrimName?.rawValue,
					availablePrims: previous.availablePrims,
					metersPerUnit: metadata.metersPerUnit ?? 1,
					upAxis: upAxis
				)
				return .none

			case .addAudioMixGroupRequested,
				.assignAudioMixGroupResourceRequested,
				.setRawComponentAttributeRequested:
				state.errorMessage = "Inspector editing requires the SwiftUsdShell runtime adapter."
				return .none

			case .setMaterialBindingSucceeded,
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
