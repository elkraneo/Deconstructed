import ComposableArchitecture
import Foundation
import SceneGraphModels
import SwiftUsdShell
import simd

public enum InspectorTarget: Equatable, Sendable {
	case sceneLayer
	case prim(path: String)
}

public enum SceneUpAxis: String, Equatable, Sendable, CaseIterable {
	case y = "Y"
	case z = "Z"

	public var displayName: String {
		switch self {
		case .y: return "Y"
		case .z: return "Z"
		}
	}
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

public struct ShellScenePlaybackData: Equatable, Sendable {
	public var startTimeCode: Double
	public var endTimeCode: Double
	public var timeCodesPerSecond: Double
	public var autoPlay: Bool?
	public var animationTrackCount: Int

	public init(
		startTimeCode: Double = 0,
		endTimeCode: Double = 0,
		timeCodesPerSecond: Double = 24,
		autoPlay: Bool? = nil,
		animationTrackCount: Int = 0
	) {
		self.startTimeCode = startTimeCode
		self.endTimeCode = endTimeCode
		self.timeCodesPerSecond = timeCodesPerSecond
		self.autoPlay = autoPlay
		self.animationTrackCount = animationTrackCount
	}

	public var hasTimeline: Bool {
		endTimeCode > startTimeCode || animationTrackCount > 0
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

public struct InspectorComponentSummary: Equatable, Sendable, Identifiable {
	public var id: String { path }
	public var path: String
	public var name: String
	public var typeName: String
	public var isActive: Bool
	public var authoredAttributes: [InspectorAuthoredAttribute]
	public var descendants: [ComponentDescendantAttributes]

	public init(
		path: String,
		name: String,
		typeName: String,
		isActive: Bool,
		authoredAttributes: [InspectorAuthoredAttribute] = [],
		descendants: [ComponentDescendantAttributes] = []
	) {
		self.path = path
		self.name = name
		self.typeName = typeName
		self.isActive = isActive
		self.authoredAttributes = authoredAttributes
		self.descendants = descendants
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
		public var primSummary: SwiftUsdShell.USDPrimSummary?
		public var materialBinding: SwiftUsdShell.USDMaterialBindingInfo?
		public var primReferences: [SwiftUsdShell.USDReference]
		public var primVariantSets: [SwiftUsdShell.USDVariantSetSummary]
		public var availableMaterials: [SwiftUsdShell.USDMaterialSummary]
		public var materialProperties: [SwiftUsdShell.USDMaterialPropertySummary]
		public var primCompositionArcs: [SwiftUsdShell.USDCompositionArcSummary]
		public var primComponents: [InspectorComponentSummary]
		public var componentAuthoredAttributesByPath: [String: [InspectorAuthoredAttribute]]
		public var componentDescendantAttributesByPath: [String: [ComponentDescendantAttributes]]
		public var meshSortingGroupMembers: [String]
		public var playbackData: ShellScenePlaybackData?
		public var playbackCurrentTime: Double
		public var isPlaying: Bool
		public var playbackSpeed: Double
		public var errorMessage: String?

		public init(
			sceneURL: URL? = nil,
			selectedNodeID: SceneNode.ID? = nil,
			layerData: SceneLayerData? = nil,
			sceneNodes: [SceneNode] = [],
			primTransform: SwiftUsdShell.USDTransformData? = nil,
			primSummary: SwiftUsdShell.USDPrimSummary? = nil,
			materialBinding: SwiftUsdShell.USDMaterialBindingInfo? = nil,
			primReferences: [SwiftUsdShell.USDReference] = [],
			primVariantSets: [SwiftUsdShell.USDVariantSetSummary] = [],
			availableMaterials: [SwiftUsdShell.USDMaterialSummary] = [],
			materialProperties: [SwiftUsdShell.USDMaterialPropertySummary] = [],
			primCompositionArcs: [SwiftUsdShell.USDCompositionArcSummary] = [],
			primComponents: [InspectorComponentSummary] = [],
			componentAuthoredAttributesByPath: [String: [InspectorAuthoredAttribute]] = [:],
			componentDescendantAttributesByPath: [String: [ComponentDescendantAttributes]] = [:],
			meshSortingGroupMembers: [String] = [],
			playbackData: ShellScenePlaybackData? = nil,
			playbackCurrentTime: Double = 0,
			isPlaying: Bool = false,
			playbackSpeed: Double = 1,
			errorMessage: String? = nil
		) {
			self.sceneURL = sceneURL
			self.selectedNodeID = selectedNodeID
			self.layerData = layerData
			self.sceneNodes = sceneNodes
			self.primTransform = primTransform
			self.primSummary = primSummary
			self.materialBinding = materialBinding
			self.primReferences = primReferences
			self.primVariantSets = primVariantSets
			self.availableMaterials = availableMaterials
			self.materialProperties = materialProperties
			self.primCompositionArcs = primCompositionArcs
			self.primComponents = primComponents
			self.componentAuthoredAttributesByPath = componentAuthoredAttributesByPath
			self.componentDescendantAttributesByPath = componentDescendantAttributesByPath
			self.meshSortingGroupMembers = meshSortingGroupMembers
			self.playbackData = playbackData
			self.playbackCurrentTime = playbackCurrentTime
			self.isPlaying = isPlaying
			self.playbackSpeed = playbackSpeed
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
		case loadPrimSummaryRequested(URL, primPath: String)
		case primSummaryLoaded(SwiftUsdShell.USDPrimSummary?)
		case loadAvailableMaterialsRequested(URL)
		case availableMaterialsLoaded([SwiftUsdShell.USDMaterialSummary])
		case loadMaterialPropertiesRequested(URL, materialPath: String)
		case materialPropertiesLoaded([SwiftUsdShell.USDMaterialPropertySummary])
		case loadPrimCompositionArcsRequested(URL, primPath: String)
		case primCompositionArcsLoaded([SwiftUsdShell.USDCompositionArcSummary])
		case loadPrimComponentsRequested(URL, primPath: String)
		case primComponentsLoaded([InspectorComponentSummary])
		case loadMeshSortingGroupMembersRequested(URL, groupPrimPath: String, candidatePrimPaths: [String])
		case meshSortingGroupMembersLoaded([String])
		case addBehaviorRequested(behaviorsContainerPath: String, triggerType: String)
		case addBehaviorSucceeded(behaviorsContainerPath: String)
		case addBehaviorFailed(String)
		case removeBehaviorRequested(behaviorsContainerPath: String, behaviorPath: String)
		case removeBehaviorSucceeded(behaviorsContainerPath: String)
		case removeBehaviorFailed(String)
		case addAnimationLibraryResourceRequested(componentPath: String, sourceURL: URL)
		case addAnimationLibraryResourceSucceeded(componentPath: String)
		case addAnimationLibraryResourceFailed(String)
		case removeAnimationLibraryResourceRequested(componentPath: String, resourcePrimPath: String)
		case removeAnimationLibraryResourceSucceeded(componentPath: String)
		case removeAnimationLibraryResourceFailed(String)
		case playbackPlayPauseRequested
		case playbackStopRequested
		case playbackScrubRequested(time: Double, isEditing: Bool)
		case playbackTick(deltaSeconds: Double)
		case primTransformEdited(SwiftUsdShell.USDTransformData)
		case persistPrimTransformRequested(URL, primPath: String, transform: SwiftUsdShell.USDTransformData)
		case primTransformPersistFailed(String)
		case setMaterialBindingRequested(materialPath: String?)
		case setMaterialBindingStrengthRequested(SwiftUsdShell.USDMaterialBindingStrength)
		case materialBindingWriteFailed(String)
		case setVariantSelectionRequested(setName: String, selectionId: String?)
		case variantSelectionWriteFailed(String)
		case setComponentActiveRequested(componentPath: String, isActive: Bool)
		case deleteComponentRequested(componentPath: String)
		case componentWriteFailed(String)
		case addReferenceRequested(SwiftUsdShell.USDReference)
		case removeReferenceRequested(SwiftUsdShell.USDReference)
		case referenceWriteFailed(String)
		case setDefaultPrimRequested(String)
		case setMetersPerUnitRequested(Double)
		case setUpAxisRequested(String)
		case stageMetadataWriteFailed(String)
		case setComponentParameterRequested(
			componentPath: String,
			attributeType: String,
			attributeName: String,
			valueLiteral: String
		)
		case setComponentParameterSucceeded(componentPath: String)
		case componentParameterWriteFailed(String)
		case addComponentRequested(componentName: String, componentIdentifier: String)
		case addComponentWriteFailed(String)
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

	private enum CancelID: Hashable {
		case persistTransform
		case playbackTicker
	}

	private func startPlaybackTickerEffect() -> Effect<Action> {
		.run { [clock] send in
			let interval: Duration = .milliseconds(33)
			let deltaSeconds = 0.033
			for await _ in clock.timer(interval: interval) {
				await send(.playbackTick(deltaSeconds: deltaSeconds))
			}
		}
		.cancellable(id: CancelID.playbackTicker, cancelInFlight: true)
	}

	@Dependency(\.sceneInspector) var sceneInspector
	@Dependency(\.continuousClock) var clock

	public var body: some ReducerOf<Self> {
		Reduce { state, action in
			switch action {
			case .sceneURLChanged(let url):
				state.sceneURL = url
				if let url {
					return .merge(
						.send(.loadSceneMetadataRequested(url)),
						.send(.loadAvailableMaterialsRequested(url))
					)
				}
				state.selectedNodeID = nil
				state.sceneNodes = []
				state.layerData = nil
				state.primTransform = nil
				state.primSummary = nil
				state.materialBinding = nil
				state.materialProperties = []
				state.primReferences = []
				state.primVariantSets = []
				state.primCompositionArcs = []
				state.primComponents = []
				state.availableMaterials = []
				return .none

			case .selectionChanged(let id):
				state.selectedNodeID = id
				state.primTransform = nil
				state.primSummary = nil
				state.materialBinding = nil
				state.materialProperties = []
				state.primReferences = []
				state.primVariantSets = []
				state.primCompositionArcs = []
				state.primComponents = []
				state.meshSortingGroupMembers = []
				guard let id, let url = state.sceneURL else {
					return .none
				}
				var effects: [Effect<Action>] = [
					.send(.loadPrimTransformRequested(url, primPath: id)),
					.send(.loadMaterialBindingRequested(url, primPath: id)),
					.send(.loadPrimReferencesRequested(url, primPath: id)),
					.send(.loadPrimVariantSetsRequested(url, primPath: id)),
					.send(.loadPrimSummaryRequested(url, primPath: id)),
					.send(.loadPrimCompositionArcsRequested(url, primPath: id)),
					.send(.loadPrimComponentsRequested(url, primPath: id)),
				]
				if state.selectedNode?.typeName == "RealityKitMeshSortingGroup" {
					let candidatePaths = flattenPrimPaths(state.sceneNodes)
					effects.append(.send(.loadMeshSortingGroupMembersRequested(
						url,
						groupPrimPath: id,
						candidatePrimPaths: candidatePaths
					)))
				}
				return .merge(effects)

			case .loadPrimTransformRequested(let url, let primPath):
				return .run { [sceneInspector] send in
					let transform = await sceneInspector.primTransform(url, primPath)
					await send(.primTransformLoaded(transform))
				}

			case .primTransformLoaded(let transform):
				// If the prim has no authored xformOp attributes (typical for a
				// freshly-inserted primitive like `def Cone "Cone1"`), the runtime
				// returns nil. Show an identity transform so the user can place
				// the new prim — the first edit will author the xformOp attrs.
				state.primTransform = transform ?? SwiftUsdShell.USDTransformData()
				return .none

			case .loadMaterialBindingRequested(let url, let primPath):
				return .run { [sceneInspector] send in
					let info = await sceneInspector.materialBinding(url, primPath)
					await send(.materialBindingLoaded(info))
				}

			case .materialBindingLoaded(let info):
				state.materialBinding = info
				guard let url = state.sceneURL,
				      let materialPath = info?.effectiveMaterialPath?.rawValue
				else {
					state.materialProperties = []
					return .none
				}
				return .send(.loadMaterialPropertiesRequested(url, materialPath: materialPath))

			case .loadMaterialPropertiesRequested(let url, let materialPath):
				return .run { [sceneInspector] send in
					let properties = await sceneInspector.materialProperties(url, materialPath)
					await send(.materialPropertiesLoaded(properties))
				}

			case .materialPropertiesLoaded(let properties):
				state.materialProperties = properties
				return .none

			case .loadPrimCompositionArcsRequested(let url, let primPath):
				return .run { [sceneInspector] send in
					let arcs = await sceneInspector.primCompositionArcs(url, primPath)
					await send(.primCompositionArcsLoaded(arcs))
				}

			case .primCompositionArcsLoaded(let arcs):
				state.primCompositionArcs = arcs
				return .none

			case .loadPrimComponentsRequested(let url, let primPath):
				return .run { [sceneInspector] send in
					let components = await sceneInspector.primComponents(url, primPath)
					await send(.primComponentsLoaded(components))
				}

			case .primComponentsLoaded(let components):
				state.primComponents = components
				return .none

			case .loadMeshSortingGroupMembersRequested(let url, let groupPath, let candidates):
				return .run { [sceneInspector] send in
					let members = await sceneInspector.meshSortingGroupMembers(url, groupPath, candidates)
					await send(.meshSortingGroupMembersLoaded(members))
				}

			case .meshSortingGroupMembersLoaded(let members):
				state.meshSortingGroupMembers = members
				return .none

			case .addBehaviorRequested(let containerPath, let triggerType):
				guard let url = state.sceneURL,
				      let selectedID = state.selectedNodeID
				else { return .none }
				return .run { [sceneInspector] send in
					do {
						_ = try await sceneInspector.addBehavior(url, containerPath, triggerType)
						await send(.addBehaviorSucceeded(behaviorsContainerPath: containerPath))
						await send(.loadPrimComponentsRequested(url, primPath: selectedID))
					} catch {
						await send(.addBehaviorFailed(error.localizedDescription))
					}
				}

			case .addBehaviorSucceeded:
				state.errorMessage = nil
				return .none

			case .addBehaviorFailed(let message):
				state.errorMessage = "Failed to add behavior: \(message)"
				return .none

			case .removeBehaviorRequested(let containerPath, let behaviorPath):
				guard let url = state.sceneURL,
				      let selectedID = state.selectedNodeID
				else { return .none }
				return .run { [sceneInspector] send in
					do {
						try await sceneInspector.removeBehavior(url, containerPath, behaviorPath)
						await send(.removeBehaviorSucceeded(behaviorsContainerPath: containerPath))
						await send(.loadPrimComponentsRequested(url, primPath: selectedID))
					} catch {
						await send(.removeBehaviorFailed(error.localizedDescription))
					}
				}

			case .removeBehaviorSucceeded:
				state.errorMessage = nil
				return .none

			case .removeBehaviorFailed(let message):
				state.errorMessage = "Failed to remove behavior: \(message)"
				return .none

			case .primTransformEdited(let transform):
				state.primTransform = transform
				guard let url = state.sceneURL, let primPath = state.selectedNodeID else {
					return .none
				}
				return .run { [clock] send in
					try? await clock.sleep(for: .milliseconds(120))
					await send(.persistPrimTransformRequested(url, primPath: primPath, transform: transform))
				}
				.cancellable(id: CancelID.persistTransform, cancelInFlight: true)

			case .persistPrimTransformRequested(let url, let primPath, let transform):
				return .run { [sceneInspector] send in
					do {
						try await sceneInspector.setPrimTransform(url, primPath, transform)
						await send(.primTransformSaveSucceeded)
					} catch {
						await send(.primTransformPersistFailed(error.localizedDescription))
					}
				}

			case .primTransformPersistFailed(let message):
				state.errorMessage = message
				return .none

			case .setMaterialBindingRequested(let materialPath):
				guard let url = state.sceneURL, let primPath = state.selectedNodeID else {
					return .none
				}
				return .run { [sceneInspector] send in
					do {
						try await sceneInspector.setMaterialBinding(url, primPath, materialPath)
						await send(.setMaterialBindingSucceeded)
						await send(.loadMaterialBindingRequested(url, primPath: primPath))
					} catch {
						await send(.materialBindingWriteFailed(error.localizedDescription))
					}
				}

			case .setMaterialBindingStrengthRequested(let strength):
				guard let url = state.sceneURL, let primPath = state.selectedNodeID else {
					return .none
				}
				return .run { [sceneInspector] send in
					do {
						try await sceneInspector.setMaterialBindingStrength(url, primPath, strength)
						await send(.setMaterialBindingStrengthSucceeded)
						await send(.loadMaterialBindingRequested(url, primPath: primPath))
					} catch {
						await send(.materialBindingWriteFailed(error.localizedDescription))
					}
				}

			case .materialBindingWriteFailed(let message):
				state.errorMessage = message
				return .none

			case .setVariantSelectionRequested(let setName, let selectionId):
				guard let url = state.sceneURL, let primPath = state.selectedNodeID else {
					return .none
				}
				return .run { [sceneInspector] send in
					do {
						try await sceneInspector.setPrimVariantSelection(url, primPath, setName, selectionId)
						await send(.setVariantSelectionSucceeded(selectionId))
						await send(.loadPrimVariantSetsRequested(url, primPath: primPath))
					} catch {
						await send(.variantSelectionWriteFailed(error.localizedDescription))
					}
				}

			case .variantSelectionWriteFailed(let message):
				state.errorMessage = message
				return .none

			case .setComponentActiveRequested(let componentPath, let isActive):
				guard let url = state.sceneURL, let primPath = state.selectedNodeID else {
					return .none
				}
				return .run { [sceneInspector] send in
					do {
						try await sceneInspector.setComponentActive(url, componentPath, isActive)
						await send(.setComponentActiveSucceeded(componentPath: componentPath, isActive: isActive))
						await send(.loadPrimComponentsRequested(url, primPath: primPath))
					} catch {
						await send(.componentWriteFailed(error.localizedDescription))
					}
				}

			case .deleteComponentRequested(let componentPath):
				guard let url = state.sceneURL, let primPath = state.selectedNodeID else {
					return .none
				}
				return .run { [sceneInspector] send in
					do {
						try await sceneInspector.deleteComponent(url, componentPath)
						await send(.deleteComponentSucceeded(componentPath: componentPath))
						await send(.loadPrimComponentsRequested(url, primPath: primPath))
					} catch {
						await send(.componentWriteFailed(error.localizedDescription))
					}
				}

			case .componentWriteFailed(let message):
				state.errorMessage = message
				return .none

			case .addReferenceRequested(let reference):
				guard let url = state.sceneURL, let primPath = state.selectedNodeID else {
					return .none
				}
				return .run { [sceneInspector] send in
					do {
						try await sceneInspector.addPrimReference(url, primPath, reference)
						await send(.primReferencesEditSucceeded)
						await send(.loadPrimReferencesRequested(url, primPath: primPath))
					} catch {
						await send(.referenceWriteFailed(error.localizedDescription))
					}
				}

			case .removeReferenceRequested(let reference):
				guard let url = state.sceneURL, let primPath = state.selectedNodeID else {
					return .none
				}
				return .run { [sceneInspector] send in
					do {
						try await sceneInspector.removePrimReference(url, primPath, reference)
						await send(.primReferencesEditSucceeded)
						await send(.loadPrimReferencesRequested(url, primPath: primPath))
					} catch {
						await send(.referenceWriteFailed(error.localizedDescription))
					}
				}

			case .referenceWriteFailed(let message):
				state.errorMessage = message
				return .none

			case .setDefaultPrimRequested(let primPath):
				guard let url = state.sceneURL else { return .none }
				return .run { [sceneInspector] send in
					do {
						try await sceneInspector.setDefaultPrim(url, primPath)
						await send(.loadSceneMetadataRequested(url))
					} catch {
						await send(.stageMetadataWriteFailed(error.localizedDescription))
					}
				}

			case .setMetersPerUnitRequested(let value):
				guard let url = state.sceneURL else { return .none }
				return .run { [sceneInspector] send in
					do {
						try await sceneInspector.setMetersPerUnit(url, value)
						await send(.loadSceneMetadataRequested(url))
					} catch {
						await send(.stageMetadataWriteFailed(error.localizedDescription))
					}
				}

			case .setUpAxisRequested(let axis):
				guard let url = state.sceneURL else { return .none }
				return .run { [sceneInspector] send in
					do {
						try await sceneInspector.setUpAxis(url, axis)
						await send(.loadSceneMetadataRequested(url))
					} catch {
						await send(.stageMetadataWriteFailed(error.localizedDescription))
					}
				}

			case .stageMetadataWriteFailed(let message):
				state.errorMessage = message
				return .none

			case .setComponentParameterRequested(let componentPath, let attributeType, let attributeName, let valueLiteral):
				guard let url = state.sceneURL, let primPath = state.selectedNodeID else {
					return .none
				}
				return .run { [sceneInspector] send in
					do {
						try await sceneInspector.setComponentParameter(url, componentPath, attributeType, attributeName, valueLiteral)
						await send(.setComponentParameterSucceeded(componentPath: componentPath))
						await send(.loadPrimComponentsRequested(url, primPath: primPath))
					} catch {
						await send(.componentParameterWriteFailed(error.localizedDescription))
					}
				}

			case .setComponentParameterSucceeded:
				return .none

			case .componentParameterWriteFailed(let message):
				state.errorMessage = message
				return .none

			case .addComponentRequested(let componentName, let componentIdentifier):
				guard let url = state.sceneURL, let primPath = state.selectedNodeID else {
					return .none
				}
				return .run { [sceneInspector] send in
					do {
						let newPath = try await sceneInspector.addComponent(url, primPath, componentName, componentIdentifier)
						await send(.addComponentSucceeded(newPath))
						await send(.loadPrimComponentsRequested(url, primPath: primPath))
					} catch {
						await send(.addComponentWriteFailed(error.localizedDescription))
					}
				}

			case .addComponentWriteFailed(let message):
				state.errorMessage = message
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

			case .loadPrimSummaryRequested(let url, let primPath):
				return .run { [sceneInspector] send in
					let summary = await sceneInspector.primSummary(url, primPath)
					await send(.primSummaryLoaded(summary))
				}

			case .primSummaryLoaded(let summary):
				state.primSummary = summary
				return .none

			case .loadAvailableMaterialsRequested(let url):
				return .run { [sceneInspector] send in
					let materials = await sceneInspector.allMaterials(url)
					await send(.availableMaterialsLoaded(materials))
				}

			case .availableMaterialsLoaded(let materials):
				state.availableMaterials = materials
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
				// metadata.defaultPrimName is the USD token (e.g. "Root"), but
				// availablePrims are full prim paths ("/Root"). Normalize to a
				// path so the Default Prim picker tag matches its selection.
				let defaultPrimPath: String?
				if let name = metadata.defaultPrimName?.rawValue, !name.isEmpty {
					defaultPrimPath = name.hasPrefix("/") ? name : "/\(name)"
				} else {
					defaultPrimPath = nil
				}
				state.layerData = SceneLayerData(
					defaultPrim: defaultPrimPath,
					availablePrims: previous.availablePrims,
					metersPerUnit: metadata.metersPerUnit ?? 1,
					upAxis: upAxis
				)
				let playback = ShellScenePlaybackData(
					startTimeCode: metadata.startTimeCode ?? 0,
					endTimeCode: metadata.endTimeCode ?? 0,
					timeCodesPerSecond: metadata.timeCodesPerSecond ?? 24,
					autoPlay: metadata.autoPlay,
					animationTrackCount: metadata.animationTracks.count
				)
				state.playbackData = playback
				state.playbackCurrentTime = playback.startTimeCode
				let shouldAutoPlay = (playback.autoPlay ?? false) && playback.hasTimeline
				state.isPlaying = shouldAutoPlay
				return shouldAutoPlay
					? startPlaybackTickerEffect()
					: .cancel(id: CancelID.playbackTicker)

			case .setRawComponentAttributeRequested:
				state.errorMessage = "Inspector editing requires the SwiftUsdShell runtime adapter."
				return .none

			case .addAudioMixGroupRequested(let componentPath):
				guard let url = state.sceneURL,
				      let selectedID = state.selectedNodeID
				else { return .none }
				let existing = (state.primComponents.first { $0.path == componentPath }?.descendants ?? [])
					.filter { d in d.authoredAttributes.first { $0.name == "file" }?.value.isEmpty ?? true }
					.map(\.path)
				return .run { [sceneInspector] send in
					do {
						_ = try await sceneInspector.addAudioMixGroup(url, componentPath, existing)
						await send(.loadPrimComponentsRequested(url, primPath: selectedID))
					} catch {
						await send(.componentParameterWriteFailed(error.localizedDescription))
					}
				}

			case .assignAudioMixGroupResourceRequested(let componentPath, let mixGroupPath, let sourceURL):
				guard let url = state.sceneURL,
				      let selectedID = state.selectedNodeID
				else { return .none }
				let existing = (state.primComponents.first { $0.path == componentPath }?.descendants ?? [])
					.filter { d in !((d.authoredAttributes.first { $0.name == "file" }?.value ?? "").isEmpty) }
					.map(\.path)
				let rootPrimPath = state.sceneNodes.first?.path ?? "/Root"
				return .run { [sceneInspector] send in
					do {
						try await sceneInspector.assignAudioMixGroupResource(
							url, componentPath, mixGroupPath, sourceURL, existing, rootPrimPath
						)
						await send(.loadPrimComponentsRequested(url, primPath: selectedID))
					} catch {
						await send(.componentParameterWriteFailed(error.localizedDescription))
					}
				}

			case .addAnimationLibraryResourceRequested(let componentPath, let sourceURL):
				guard let url = state.sceneURL,
				      let selectedID = state.selectedNodeID
				else { return .none }
				let existing = (state.primComponents.first { $0.path == componentPath }?.descendants ?? [])
					.filter { d in !((d.authoredAttributes.first { $0.name == "file" }?.value ?? "").isEmpty) }
					.map(\.path)
				return .run { [sceneInspector] send in
					do {
						_ = try await sceneInspector.addAnimationLibraryResource(url, componentPath, sourceURL, existing)
						await send(.addAnimationLibraryResourceSucceeded(componentPath: componentPath))
						await send(.loadPrimComponentsRequested(url, primPath: selectedID))
					} catch {
						await send(.addAnimationLibraryResourceFailed(error.localizedDescription))
					}
				}

			case .addAnimationLibraryResourceSucceeded:
				state.errorMessage = nil
				return .none

			case .addAnimationLibraryResourceFailed(let message):
				state.errorMessage = "Failed to add animation resource: \(message)"
				return .none

			case .removeAnimationLibraryResourceRequested(_, let resourcePrimPath):
				guard let url = state.sceneURL,
				      let selectedID = state.selectedNodeID
				else { return .none }
				return .run { [sceneInspector] send in
					do {
						try await sceneInspector.removeAnimationLibraryResource(url, resourcePrimPath)
						await send(.removeAnimationLibraryResourceSucceeded(componentPath: resourcePrimPath))
						await send(.loadPrimComponentsRequested(url, primPath: selectedID))
					} catch {
						await send(.removeAnimationLibraryResourceFailed(error.localizedDescription))
					}
				}

			case .removeAnimationLibraryResourceSucceeded:
				state.errorMessage = nil
				return .none

			case .removeAnimationLibraryResourceFailed(let message):
				state.errorMessage = "Failed to remove animation resource: \(message)"
				return .none

			case .playbackPlayPauseRequested:
				guard let playback = state.playbackData, playback.hasTimeline else { return .none }
				state.isPlaying.toggle()
				if state.isPlaying {
					if state.playbackCurrentTime >= playback.endTimeCode {
						state.playbackCurrentTime = playback.startTimeCode
					}
					return startPlaybackTickerEffect()
				} else {
					return .cancel(id: CancelID.playbackTicker)
				}

			case .playbackStopRequested:
				state.isPlaying = false
				state.playbackCurrentTime = state.playbackData?.startTimeCode ?? 0
				return .cancel(id: CancelID.playbackTicker)

			case .playbackScrubRequested(let time, let isEditing):
				guard let playback = state.playbackData else { return .none }
				let clamped = min(max(time, playback.startTimeCode), playback.endTimeCode)
				state.playbackCurrentTime = clamped
				if isEditing && state.isPlaying {
					state.isPlaying = false
					return .cancel(id: CancelID.playbackTicker)
				}
				return .none

			case .playbackTick(let deltaSeconds):
				guard let playback = state.playbackData, state.isPlaying else { return .none }
				let advance = deltaSeconds * playback.timeCodesPerSecond * state.playbackSpeed
				let next = state.playbackCurrentTime + advance
				if next >= playback.endTimeCode {
					state.playbackCurrentTime = playback.endTimeCode
					state.isPlaying = false
					return .cancel(id: CancelID.playbackTicker)
				}
				state.playbackCurrentTime = next
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
