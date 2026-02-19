import ComposableArchitecture
import DeconstructedUSDInterop
import Foundation
import InspectorModels
import SceneGraphModels
import simd
import USDInterfaces
import USDInteropAdvancedCore

@Reducer
public struct InspectorFeature {
	@ObservableState
	public struct State: Equatable {
		public var sceneURL: URL?
		public var selectedNodeID: SceneNode.ID?
		public var primVariantScopePath: String?
		public var layerData: SceneLayerData?
		public var playbackData: ScenePlaybackData?
		public var primAttributes: USDPrimAttributes?
		public var primTransform: USDTransformData?
		public var primVariantSets: [USDVariantSetDescriptor]
		public var primReferences: [USDReference]
		public var primMaterialBinding: String?
		public var primMaterialBindingStrength: USDMaterialBindingStrength?
		public var componentActiveByPath: [String: Bool]
		public var componentAuthoredAttributesByPath:
			[String: [USDPrimAttributes.AuthoredAttribute]]
		public var componentDescendantAttributesByPath:
			[String: [ComponentDescendantAttributes]]
		public var componentMutationRevisionByPath: [String: Int]
		public var boundMaterial: USDMaterialInfo?
		public var availableMaterials: [USDMaterialInfo]
		public var sceneNodes: [SceneNode]
		public var isLoading: Bool
		public var errorMessage: String?
		public var primIsLoading: Bool
		public var primErrorMessage: String?
		public var pendingPrimLoads: Set<PrimLoadSection>
		public var meshSortingGroupMembers: [String]
		public var playbackIsPlaying: Bool
		public var playbackCurrentTime: Double
		public var playbackSpeed: Double
		public var playbackIsScrubbing: Bool

		public init(
			sceneURL: URL? = nil,
			selectedNodeID: SceneNode.ID? = nil,
			primVariantScopePath: String? = nil,
			layerData: SceneLayerData? = nil,
			playbackData: ScenePlaybackData? = nil,
			primAttributes: USDPrimAttributes? = nil,
			primTransform: USDTransformData? = nil,
			primVariantSets: [USDVariantSetDescriptor] = [],
			primReferences: [USDReference] = [],
			primMaterialBinding: String? = nil,
			primMaterialBindingStrength: USDMaterialBindingStrength? = nil,
			componentActiveByPath: [String: Bool] = [:],
			componentAuthoredAttributesByPath: [String: [USDPrimAttributes.AuthoredAttribute]] = [:],
			componentDescendantAttributesByPath: [String: [ComponentDescendantAttributes]] = [:],
			componentMutationRevisionByPath: [String: Int] = [:],
			boundMaterial: USDMaterialInfo? = nil,
			availableMaterials: [USDMaterialInfo] = [],
			sceneNodes: [SceneNode] = [],
			isLoading: Bool = false,
			errorMessage: String? = nil,
			primIsLoading: Bool = false,
			primErrorMessage: String? = nil,
			pendingPrimLoads: Set<PrimLoadSection> = [],
			meshSortingGroupMembers: [String] = [],
			playbackIsPlaying: Bool = false,
			playbackCurrentTime: Double = 0,
			playbackSpeed: Double = 1.0,
			playbackIsScrubbing: Bool = false
		) {
			self.sceneURL = sceneURL
			self.selectedNodeID = selectedNodeID
			self.primVariantScopePath = primVariantScopePath
			self.layerData = layerData
			self.playbackData = playbackData
			self.primAttributes = primAttributes
			self.primTransform = primTransform
			self.primVariantSets = primVariantSets
			self.primReferences = primReferences
			self.primMaterialBinding = primMaterialBinding
			self.primMaterialBindingStrength = primMaterialBindingStrength
			self.componentActiveByPath = componentActiveByPath
			self.componentAuthoredAttributesByPath = componentAuthoredAttributesByPath
			self.componentDescendantAttributesByPath = componentDescendantAttributesByPath
			self.componentMutationRevisionByPath = componentMutationRevisionByPath
			self.boundMaterial = boundMaterial
			self.availableMaterials = availableMaterials
			self.sceneNodes = sceneNodes
			self.isLoading = isLoading
			self.errorMessage = errorMessage
			self.primIsLoading = primIsLoading
			self.primErrorMessage = primErrorMessage
			self.pendingPrimLoads = pendingPrimLoads
			self.meshSortingGroupMembers = meshSortingGroupMembers
			self.playbackIsPlaying = playbackIsPlaying
			self.playbackCurrentTime = playbackCurrentTime
			self.playbackSpeed = playbackSpeed
			self.playbackIsScrubbing = playbackIsScrubbing
		}

		public var currentTarget: InspectorTarget {
			if let selectedNodeID {
				return .prim(path: selectedNodeID)
			}
			return .sceneLayer
		}

		public var selectedNode: SceneNode? {
			guard let selectedNodeID else {
				return nil
			}
			return findNode(id: selectedNodeID, in: sceneNodes)
		}

		}

	public enum Action: BindableAction {
		case binding(BindingAction<State>)
		case sceneURLChanged(URL?)
		case selectionChanged(SceneNode.ID?)
		case sceneGraphUpdated([SceneNode])
		case sceneMetadataLoaded(SceneLayerData, ScenePlaybackData)
		case sceneMetadataLoadFailed(String)
		case primAttributesLoaded(USDPrimAttributes)
		case primAttributesLoadFailed(String)
		case primTransformLoaded(USDTransformData)
		case primTransformLoadFailed(String)
		case primTransformChanged(USDTransformData)
		case primTransformSaveSucceeded
		case primTransformSaveFailed(String)
		case primVariantSetsLoaded([USDVariantSetDescriptor])
		case primVariantSetsLoadFailed(String)
		case setVariantSelection(setName: String, selectionId: String?)
		case setVariantSelectionSucceeded([USDVariantSetDescriptor])
		case setVariantSelectionFailed(String)
		case primReferencesLoaded([USDReference])
		case primReferencesLoadFailed(String)
		case addReferenceRequested(USDReference)
		case removeReferenceRequested(USDReference)
		case replaceReferenceRequested(old: USDReference, new: USDReference)
		case primReferencesEditSucceeded
		case primReferencesEditFailed(String)
		case primMaterialBindingLoaded(String?, USDMaterialBindingStrength?)
		case availableMaterialsLoaded([USDMaterialInfo])
		case setMaterialBinding(String?)
		case setMaterialBindingSucceeded
		case setMaterialBindingFailed(String)
		case setMaterialBindingStrength(USDMaterialBindingStrength)
		case setMaterialBindingStrengthSucceeded
		case setMaterialBindingStrengthFailed(String)
		case componentActivationLoaded([String: Bool])
		case componentAuthoredAttributesLoaded(
			[String: [USDPrimAttributes.AuthoredAttribute]]
		)
		case componentDescendantAttributesLoaded(
			[String: [ComponentDescendantAttributes]]
		)
		case componentMutationRefreshed(
			componentPath: String,
			authoredAttributes: [USDPrimAttributes.AuthoredAttribute],
			descendantAttributes: [ComponentDescendantAttributes],
			revision: Int
		)
		case meshSortingGroupMembersLoaded([String])
		case addComponentRequested(InspectorComponentDefinition)
		case addComponentSucceeded(String)
		case addComponentFailed(String)
		case setComponentActiveRequested(componentPath: String, isActive: Bool)
		case setComponentActiveSucceeded(componentPath: String, isActive: Bool)
		case setComponentActiveFailed(String)
		case setComponentParameterRequested(
			componentPath: String,
			componentIdentifier: String,
			parameterKey: String,
			value: InspectorComponentParameterValue
		)
		case setComponentParameterSucceeded(
			componentPath: String,
			attributeName: String
		)
		case setComponentParameterFailed(String)
		case addAudioLibraryResourceRequested(componentPath: String, sourceURL: URL)
		case addAudioLibraryResourceSucceeded(componentPath: String)
		case addAudioLibraryResourceFailed(String)
		case removeAudioLibraryResourceRequested(
			componentPath: String,
			resourceKey: String
		)
		case removeAudioLibraryResourceSucceeded(componentPath: String)
		case removeAudioLibraryResourceFailed(String)
		case addAnimationLibraryResourceRequested(
			componentPath: String,
			sourceURL: URL
		)
		case addAnimationLibraryResourceSucceeded(componentPath: String)
		case addAnimationLibraryResourceFailed(String)
		case removeAnimationLibraryResourceRequested(
			componentPath: String,
			resourcePrimPath: String
		)
		case removeAnimationLibraryResourceSucceeded(componentPath: String)
		case removeAnimationLibraryResourceFailed(String)
		case setRawComponentAttributeRequested(
			componentPath: String,
			attributeType: String,
			attributeName: String,
			valueLiteral: String
		)
		case setRawComponentAttributeSucceeded(
			componentPath: String,
			attributeName: String
		)
		case setRawComponentAttributeFailed(String)
		case setMeshSortingGroupDepthPassRequested(String)
		case setMeshSortingGroupDepthPassSucceeded
		case setMeshSortingGroupDepthPassFailed(String)
		case deleteComponentRequested(componentPath: String)
		case deleteComponentSucceeded(componentPath: String)
		case deleteComponentFailed(String)
		case refreshLayerData

		case defaultPrimChanged(String)
		case metersPerUnitChanged(Double)
		case upAxisChanged(UpAxis)
		case convertVariantsToConfigurationsTapped

		case layerDataUpdateSucceeded
		case layerDataUpdateFailed(String)

		case playbackPlayPauseTapped
		case playbackStopTapped
		case playbackScrubbed(Double, isEditing: Bool)
		case playbackTick
	}

	@Dependency(\.continuousClock) var clock

	public init() {}

	public var body: some ReducerOf<Self> {
		BindingReducer()

		Reduce { state, action in
			switch action {
			case .binding:
				return .none

			case .sceneURLChanged(let url):
				print(
					"[InspectorFeature] sceneURLChanged: \(url?.lastPathComponent ?? "nil")"
				)
				state.sceneURL = url
				state.selectedNodeID = nil
				state.primVariantScopePath = nil
				state.errorMessage = nil
				state.layerData = nil
				state.playbackData = nil
				state.primAttributes = nil
				state.primTransform = nil
				state.primVariantSets = []
				state.primReferences = []
				state.primMaterialBinding = nil
				state.primMaterialBindingStrength = nil
				state.componentActiveByPath = [:]
				state.componentAuthoredAttributesByPath = [:]
				state.componentDescendantAttributesByPath = [:]
				state.componentMutationRevisionByPath = [:]
				state.boundMaterial = nil
				state.availableMaterials = []
				state.primIsLoading = false
				state.primErrorMessage = nil
				state.pendingPrimLoads = []
				state.meshSortingGroupMembers = []
				state.sceneNodes = []
				state.playbackIsPlaying = false
				state.playbackCurrentTime = 0
				state.playbackIsScrubbing = false
				guard let url else {
					state.isLoading = false
					return .cancel(id: PlaybackTimerID.playback)
				}
				state.isLoading = true
				return .merge(
					.run { send in
						await loadLayerData(url: url, send: send)
					},
					.cancel(id: PlaybackTimerID.playback),
					.cancel(id: PrimVariantSelectionCancellationID.apply),
					.cancel(id: PrimAttributesLoadCancellationID.load)
				)

			case .selectionChanged(let nodeID):
				state.selectedNodeID = nodeID
				state.primVariantScopePath = nil
				state.primAttributes = nil
				state.primTransform = nil
				state.primVariantSets = []
				state.primReferences = []
				state.primMaterialBinding = nil
				state.primMaterialBindingStrength = nil
				state.componentActiveByPath = [:]
				state.componentAuthoredAttributesByPath = [:]
				state.componentDescendantAttributesByPath = [:]
				state.componentMutationRevisionByPath = [:]
				state.boundMaterial = nil
				state.primErrorMessage = nil
				state.pendingPrimLoads = []
				state.meshSortingGroupMembers = []
				guard let nodeID, let url = state.sceneURL else {
					state.primIsLoading = false
					return .none
				}
				let materialBindingPrimPath = resolvedMaterialBindingPrimPath(
					from: nodeID,
					nodes: state.sceneNodes
				)
				let variantScopePath = resolvedVariantScopePrimPath(
					from: nodeID,
					url: url
				)
				let sceneNodesSnapshot = state.sceneNodes
				state.primVariantScopePath = variantScopePath
				state.pendingPrimLoads = [
					.attributes,
					.transform,
					.variants,
					.references,
					.materialBinding,
					.materials,
				]
				state.primIsLoading = true
				return .merge(
					.cancel(id: PrimVariantSelectionCancellationID.apply),
					.run { send in
						let materials = DeconstructedUSDInterop.allMaterials(url: url)
						await send(.availableMaterialsLoaded(materials))

						if let attributes = DeconstructedUSDInterop.getPrimAttributes(
							url: url,
							primPath: nodeID
						) {
							await send(.primAttributesLoaded(attributes))
						} else {
							await send(.primAttributesLoadFailed("No prim data available."))
						}

						if let transform = DeconstructedUSDInterop.getPrimTransform(
							url: url,
							primPath: nodeID
						) {
							await send(.primTransformLoaded(transform))
						} else {
							await send(
								.primTransformLoadFailed("No transform data available.")
							)
						}

						do {
							let variantSets = try DeconstructedUSDInterop.listPrimVariantSets(
								url: url,
								primPath: variantScopePath
							)
							await send(.primVariantSetsLoaded(variantSets))
						} catch {
							await send(.primVariantSetsLoadFailed(error.localizedDescription))
						}

						let references = DeconstructedUSDInterop.getPrimReferences(
							url: url,
							primPath: nodeID
						)
						await send(.primReferencesLoaded(references))

						let binding = DeconstructedUSDInterop.materialBinding(
							url: url,
							primPath: materialBindingPrimPath
						)
						let strength = DeconstructedUSDInterop.materialBindingStrength(
							url: url,
							primPath: materialBindingPrimPath
						)
						await send(.primMaterialBindingLoaded(binding, strength))

						let componentStates = loadComponentActivationState(
							selectedPrimPath: nodeID,
							sceneNodes: sceneNodesSnapshot,
							url: url
						)
						await send(.componentActivationLoaded(componentStates))
						var componentAttributes:
							[String: [USDPrimAttributes.AuthoredAttribute]] = [:]
						var componentDescendants:
							[String: [ComponentDescendantAttributes]] = [:]
						for componentPath in componentStates.keys {
							if let attrs = DeconstructedUSDInterop.getPrimAttributes(
								url: url,
								primPath: componentPath
							)?.authoredAttributes {
								componentAttributes[componentPath] =
									mergedComponentAuthoredAttributes(
										componentPath: componentPath,
										authoredAttributes: attrs,
										url: url
									)
							}
							let descendants = loadComponentDescendantAttributes(
								componentPath: componentPath,
								sceneNodes: sceneNodesSnapshot,
								url: url
							)
							if !descendants.isEmpty {
								componentDescendants[componentPath] = descendants
							}
						}
						await send(.componentAuthoredAttributesLoaded(componentAttributes))
						await send(
							.componentDescendantAttributesLoaded(componentDescendants)
						)
						let groupMembers = loadMeshSortingGroupMembers(
							selectedPrimPath: nodeID,
							sceneNodes: sceneNodesSnapshot,
							url: url
						)
						await send(.meshSortingGroupMembersLoaded(groupMembers))
					}
					.cancellable(
						id: PrimAttributesLoadCancellationID.load,
						cancelInFlight: true
					)
				)

			case .sceneGraphUpdated(let nodes):
				print("[InspectorFeature] sceneGraphUpdated: \(nodes.count) root nodes")
				state.sceneNodes = nodes
				let availablePrims = extractAvailablePrims(from: nodes)
				print(
					"[InspectorFeature] Extracted \(availablePrims.count) available prims"
				)
				if var layerData = state.layerData {
					// Layer data already loaded, update it with prims
					layerData.availablePrims = availablePrims
					state.layerData = layerData
					print("[InspectorFeature] Updated layerData with availablePrims")
				}
				return .none

			case .sceneMetadataLoaded(let layerData, let playbackData):
				print(
					"[InspectorFeature] layerDataLoaded: defaultPrim=\(layerData.defaultPrim ?? "nil"), mpu=\(layerData.metersPerUnit), upAxis=\(layerData.upAxis)"
				)
				var updatedLayerData = layerData
				// If we have scene nodes, use them to populate availablePrims
				if !state.sceneNodes.isEmpty {
					updatedLayerData.availablePrims = extractAvailablePrims(
						from: state.sceneNodes
					)
					print(
						"[InspectorFeature] Applied \(updatedLayerData.availablePrims.count) prims from scene nodes"
					)
				}
				state.layerData = updatedLayerData
				state.playbackData = playbackData
				state.isLoading = false
				state.errorMessage = nil
				state.playbackCurrentTime = playbackData.startTimeCode
				state.playbackIsPlaying =
					(playbackData.autoPlay ?? false) && playbackData.hasTimeline
				state.playbackIsScrubbing = false
				if state.playbackIsPlaying {
					return startPlaybackTimer(state: state, clock: clock)
				}
				return .none

			case .sceneMetadataLoadFailed(let message):
				state.errorMessage = message
				state.isLoading = false
				return .none

			case .primAttributesLoaded(let attributes):
				state.primAttributes = attributes
				state.primErrorMessage = nil
				completePrimLoad(state: &state, section: .attributes)
				return .none

			case .primAttributesLoadFailed(let message):
				state.primAttributes = nil
				state.primErrorMessage = message
				completePrimLoad(state: &state, section: .attributes)
				return .none

			case .primTransformLoaded(let transform):
				state.primTransform = transform
				state.primErrorMessage = nil
				completePrimLoad(state: &state, section: .transform)
				return .none

			case .primTransformLoadFailed(let message):
				state.primTransform = nil
				state.primErrorMessage = message
				completePrimLoad(state: &state, section: .transform)
				return .none

			case .primVariantSetsLoaded(let sets):
				state.primVariantSets = sets
				completePrimLoad(state: &state, section: .variants)
				return .none

			case .primVariantSetsLoadFailed(let message):
				state.primVariantSets = []
				state.primErrorMessage = message
				completePrimLoad(state: &state, section: .variants)
				return .none

			case .setVariantSelection(let setName, let selectionId):
				guard let url = state.sceneURL else {
					return .none
				}
				let primPath = state.primVariantScopePath ?? state.selectedNodeID
				guard let primPath else {
					return .none
				}
				return .run { send in
					do {
						try DeconstructedUSDInterop.setPrimVariantSelection(
							url: url,
							primPath: primPath,
							setName: setName,
							selectionId: selectionId,
							editTarget: .rootLayer,
							persist: true
						)
						let refreshed = try DeconstructedUSDInterop.listPrimVariantSets(
							url: url,
							primPath: primPath
						)
						let normalizedSelection =
							selectionId?.isEmpty == true ? nil : selectionId
						let appliedSelection =
							refreshed
							.first(where: { $0.name == setName })?
							.selectedOptionId
						guard appliedSelection == normalizedSelection else {
							let requested = normalizedSelection ?? "None"
							let actual = appliedSelection ?? "None"
							throw NSError(
								domain: "InspectorFeature",
								code: 1,
								userInfo: [
									NSLocalizedDescriptionKey:
										"Variant selection did not apply for '\(setName)'. Requested \(requested), got \(actual)."
								]
							)
						}
						if let transform = DeconstructedUSDInterop.getPrimTransform(
							url: url,
							primPath: primPath
						) {
							await send(.primTransformLoaded(transform))
						} else {
							await send(
								.primTransformLoadFailed("No transform data available.")
							)
						}
						await send(.setVariantSelectionSucceeded(refreshed))
					} catch {
						await send(.setVariantSelectionFailed(error.localizedDescription))
					}
				}
				.cancellable(
					id: PrimVariantSelectionCancellationID.apply,
					cancelInFlight: true
				)

			case .setVariantSelectionSucceeded(let sets):
				state.primVariantSets = sets
				state.primErrorMessage = nil
				return .none

			case .setVariantSelectionFailed(let message):
				state.primErrorMessage = "Failed to set variant: \(message)"
				return .none

			case .primReferencesLoaded(let references):
				state.primReferences = references
				completePrimLoad(state: &state, section: .references)
				return .none

			case .primReferencesLoadFailed(let message):
				state.primReferences = []
				state.primErrorMessage = message
				completePrimLoad(state: &state, section: .references)
				return .none

			case .addReferenceRequested(let reference):
				guard let url = state.sceneURL, let primPath = state.selectedNodeID
				else {
					return .none
				}
				return .run { send in
					do {
						try DeconstructedUSDInterop.addPrimReference(
							url: url,
							primPath: primPath,
							reference: reference,
							editTarget: .rootLayer
						)
						let updated = DeconstructedUSDInterop.getPrimReferences(
							url: url,
							primPath: primPath
						)
						await send(.primReferencesLoaded(updated))
						await send(.primReferencesEditSucceeded)
					} catch {
						await send(.primReferencesEditFailed(error.localizedDescription))
					}
				}

			case .removeReferenceRequested(let reference):
				guard let url = state.sceneURL, let primPath = state.selectedNodeID
				else {
					return .none
				}
				return .run { send in
					do {
						try DeconstructedUSDInterop.removePrimReference(
							url: url,
							primPath: primPath,
							reference: reference,
							editTarget: .rootLayer
						)
						let updated = DeconstructedUSDInterop.getPrimReferences(
							url: url,
							primPath: primPath
						)
						await send(.primReferencesLoaded(updated))
						await send(.primReferencesEditSucceeded)
					} catch {
						await send(.primReferencesEditFailed(error.localizedDescription))
					}
				}

			case .replaceReferenceRequested(let old, let new):
				guard let url = state.sceneURL, let primPath = state.selectedNodeID
				else {
					return .none
				}
				return .run { send in
					do {
						try DeconstructedUSDInterop.removePrimReference(
							url: url,
							primPath: primPath,
							reference: old,
							editTarget: .rootLayer
						)
						try DeconstructedUSDInterop.addPrimReference(
							url: url,
							primPath: primPath,
							reference: new,
							editTarget: .rootLayer
						)
						let updated = DeconstructedUSDInterop.getPrimReferences(
							url: url,
							primPath: primPath
						)
						await send(.primReferencesLoaded(updated))
						await send(.primReferencesEditSucceeded)
					} catch {
						await send(.primReferencesEditFailed(error.localizedDescription))
					}
				}

			case .primReferencesEditSucceeded:
				state.primErrorMessage = nil
				return .none

			case .primReferencesEditFailed(let message):
				state.primErrorMessage = "Failed to edit references: \(message)"
				return .none

			case .primMaterialBindingLoaded(let binding, let strength):
				state.primMaterialBinding = normalizeMaterialPath(binding)
				state.primMaterialBindingStrength = strength
				updateBoundMaterial(state: &state)
				completePrimLoad(state: &state, section: .materialBinding)
				return .none

			case .availableMaterialsLoaded(let materials):
				state.availableMaterials = materials
				updateBoundMaterial(state: &state)
				completePrimLoad(state: &state, section: .materials)
				return .none

			case .componentActivationLoaded(let states):
				state.componentActiveByPath = states
				return .none

			case .componentAuthoredAttributesLoaded(let attributesByPath):
				for (path, attributes) in attributesByPath {
					state.componentAuthoredAttributesByPath[path] = attributes
					let descendants =
						state.componentDescendantAttributesByPath[path] ?? []
					let normalizedDescendants = normalizedAudioLibraryDescendants(
						componentPath: path,
						descendantAttributes: descendants,
						componentAuthoredAttributes: attributes
					)
					state.componentDescendantAttributesByPath[path] =
						normalizedDescendants
				}
				return .none

			case .componentDescendantAttributesLoaded(let attributesByPath):
				for (path, attributes) in attributesByPath {
					let componentAttributes =
						state.componentAuthoredAttributesByPath[path] ?? []
					let normalizedDescendants = normalizedAudioLibraryDescendants(
						componentPath: path,
						descendantAttributes: attributes,
						componentAuthoredAttributes: componentAttributes
					)
					state.componentDescendantAttributesByPath[path] =
						normalizedDescendants
				}
				return .none

			case let .componentMutationRefreshed(
				componentPath,
				authoredAttributes,
				descendantAttributes,
				revision
			):
				guard state.componentMutationRevisionByPath[componentPath] == revision else {
					return .none
				}
				if let url = state.sceneURL {
					state.componentAuthoredAttributesByPath[componentPath] =
						mergedComponentAuthoredAttributes(
							componentPath: componentPath,
							authoredAttributes: authoredAttributes,
							url: url
						)
				} else {
					state.componentAuthoredAttributesByPath[componentPath] =
						authoredAttributes
				}
				let normalizedDescendants = normalizedAudioLibraryDescendants(
					componentPath: componentPath,
					descendantAttributes: descendantAttributes,
					componentAuthoredAttributes:
						state.componentAuthoredAttributesByPath[componentPath] ?? []
				)
				state.componentDescendantAttributesByPath[componentPath] =
					normalizedDescendants
				return .none

			case .meshSortingGroupMembersLoaded(let members):
				state.meshSortingGroupMembers = members
				return .none

			case .setMaterialBinding(let materialPath):
				guard let url = state.sceneURL, let primPath = state.selectedNodeID
				else {
					return .none
				}
				let bindingPrimPath = resolvedMaterialBindingPrimPath(
					from: primPath,
					nodes: state.sceneNodes
				)
				let normalizedMaterialPath = normalizeMaterialPath(materialPath)
				return .run { send in
					do {
						if let normalizedMaterialPath {
							print(
								"[InspectorFeature] setMaterialBinding requested: selectedPrim=\(primPath), bindingPrim=\(bindingPrimPath), material=\(normalizedMaterialPath)"
							)
							try DeconstructedUSDInterop.setMaterialBinding(
								url: url,
								primPath: bindingPrimPath,
								materialPath: normalizedMaterialPath,
								editTarget: .rootLayer
							)
						} else {
							try DeconstructedUSDInterop.clearMaterialBinding(
								url: url,
								primPath: bindingPrimPath,
								editTarget: .rootLayer
							)
						}
						let refreshed = DeconstructedUSDInterop.materialBinding(
							url: url,
							primPath: bindingPrimPath
						)
						let refreshedStrength =
							DeconstructedUSDInterop.materialBindingStrength(
								url: url,
								primPath: bindingPrimPath
							)
						print(
							"[InspectorFeature] Final material binding: \(normalizeMaterialPath(refreshed) ?? "nil"), strength=\(String(describing: refreshedStrength))"
						)
						await send(.primMaterialBindingLoaded(refreshed, refreshedStrength))
						await send(.setMaterialBindingSucceeded)
					} catch {
						await send(.setMaterialBindingFailed(error.localizedDescription))
					}
				}

			case .setMaterialBindingSucceeded:
				return .none

			case .setMaterialBindingFailed(let message):
				state.primErrorMessage = message
				return .none

			case .setMaterialBindingStrength(let strength):
				guard let url = state.sceneURL, let primPath = state.selectedNodeID
				else {
					return .none
				}
				state.primMaterialBindingStrength = strength
				let bindingPrimPath = resolvedMaterialBindingPrimPath(
					from: primPath,
					nodes: state.sceneNodes
				)
				return .run { send in
					do {
						try DeconstructedUSDInterop.setMaterialBindingStrength(
							url: url,
							primPath: bindingPrimPath,
							strength: strength,
							editTarget: .rootLayer
						)
						await send(.setMaterialBindingStrengthSucceeded)
					} catch {
						await send(
							.setMaterialBindingStrengthFailed(error.localizedDescription)
						)
					}
				}

			case .setMaterialBindingStrengthSucceeded:
				return .none

			case .setMaterialBindingStrengthFailed(let message):
				state.primErrorMessage = message
				return .none

			case .addComponentRequested(let component):
				guard let url = state.sceneURL,
					let selectedPrimPath = state.selectedNodeID
				else {
					return .none
				}
				guard component.isEnabledForAuthoring else {
					state.primErrorMessage =
						"'\(component.name)' is listed but not implemented yet."
					return .none
				}
				let targetPrimPath: String =
					switch component.placement {
					case .selectedPrim:
						selectedPrimPath
					case .rootPrim:
						state.sceneNodes.first?.path ?? "/Root"
					}
				guard findNode(id: targetPrimPath, in: state.sceneNodes) != nil else {
					state.primErrorMessage = "Target prim not found: \(targetPrimPath)"
					return .none
				}
				let existingComponents =
					DeconstructedUSDInterop.listRealityKitComponentPrims(
						url: url,
						parentPrimPath: targetPrimPath
					)
				if existingComponents.contains(where: {
					$0.primName == component.authoredPrimName
				}) {
					state.primErrorMessage =
						"Component '\(component.name)' already exists on this prim."
					return .none
				}
				return .run { send in
					do {
						let componentPath =
							try DeconstructedUSDInterop.addRealityKitComponent(
								url: url,
								primPath: targetPrimPath,
								componentName: component.authoredPrimName,
								componentIdentifier: component.identifier
							)
						await send(.addComponentSucceeded(componentPath))
					} catch {
						await send(.addComponentFailed(error.localizedDescription))
					}
				}

			case .addComponentSucceeded:
				state.primErrorMessage = nil
				return .none

			case .addComponentFailed(let message):
				state.primErrorMessage = "Failed to add component: \(message)"
				return .none

			case .setComponentActiveRequested(let componentPath, let isActive):
				guard let url = state.sceneURL else {
					return .none
				}
				return .run { send in
					do {
						try DeconstructedUSDInterop.setRealityKitComponentActive(
							url: url,
							componentPrimPath: componentPath,
							isActive: isActive
						)
						await send(
							.setComponentActiveSucceeded(
								componentPath: componentPath,
								isActive: isActive
							)
						)
					} catch {
						await send(.setComponentActiveFailed(error.localizedDescription))
					}
				}

			case .setComponentActiveSucceeded(let componentPath, let isActive):
				state.componentActiveByPath[componentPath] = isActive
				state.primErrorMessage = nil
				return .none

			case .setComponentActiveFailed(let message):
				state.primErrorMessage = "Failed to update component state: \(message)"
				return .none

			case .setComponentParameterRequested(
				let componentPath,
				let componentIdentifier,
				let parameterKey,
				let value
			):
				guard let url = state.sceneURL else {
					return .none
				}
				let mutationRevision = (state.componentMutationRevisionByPath[componentPath] ?? 0) + 1
				state.componentMutationRevisionByPath[componentPath] = mutationRevision
				let sceneNodesSnapshot = state.sceneNodes
				if componentIdentifier == "RealityKit.MeshSorting" {
					return .run { send in
						do {
							try applyMeshSortingParameterChange(
								url: url,
								componentPath: componentPath,
								parameterKey: parameterKey,
								value: value
							)
							let refreshed =
								DeconstructedUSDInterop.getPrimAttributes(
									url: url,
									primPath: componentPath
								)?.authoredAttributes ?? []
							let descendants = loadComponentDescendantAttributes(
								componentPath: componentPath,
								sceneNodes: sceneNodesSnapshot,
								url: url
							)
							await send(
								.componentMutationRefreshed(
									componentPath: componentPath,
									authoredAttributes: refreshed,
									descendantAttributes: descendants,
									revision: mutationRevision
								)
							)
							await send(
								.setComponentParameterSucceeded(
									componentPath: componentPath,
									attributeName: parameterKey
								)
							)
						} catch {
							await send(
								.setComponentParameterFailed(error.localizedDescription)
							)
						}
					}
					.cancellable(
						id: ComponentParameterMutationCancellationID(
							componentPath: componentPath
						),
						cancelInFlight: true
					)
				}
					if componentIdentifier == "RealityKit.CharacterController" {
						return .run { send in
						do {
							let maybeUpdatedTransform = try applyCharacterControllerParameterChange(
								url: url,
								componentPath: componentPath,
								parameterKey: parameterKey,
								value: value
							)
							let refreshed =
								DeconstructedUSDInterop.getPrimAttributes(
									url: url,
									primPath: componentPath
								)?.authoredAttributes ?? []
							let descendants = loadComponentDescendantAttributes(
								componentPath: componentPath,
								sceneNodes: sceneNodesSnapshot,
								url: url
							)
							await send(
								.componentMutationRefreshed(
									componentPath: componentPath,
									authoredAttributes: refreshed,
									descendantAttributes: descendants,
									revision: mutationRevision
								)
							)
							if let maybeUpdatedTransform {
								await send(.primTransformLoaded(maybeUpdatedTransform))
							}
							await send(
								.setComponentParameterSucceeded(
									componentPath: componentPath,
									attributeName: parameterKey
								)
							)
						} catch {
							await send(
								.setComponentParameterFailed(error.localizedDescription)
							)
						}
					}
					.cancellable(
						id: ComponentParameterMutationCancellationID(
							componentPath: componentPath
						),
						cancelInFlight: true
						)
					}
					if componentIdentifier == "RealityKit.Anchoring" {
						return .run { send in
							do {
								try applyAnchoringParameterChange(
									url: url,
									componentPath: componentPath,
									parameterKey: parameterKey,
									value: value
								)
								let refreshed =
									DeconstructedUSDInterop.getPrimAttributes(
										url: url,
										primPath: componentPath
									)?.authoredAttributes ?? []
								let descendants = loadComponentDescendantAttributes(
									componentPath: componentPath,
									sceneNodes: sceneNodesSnapshot,
									url: url
								)
								await send(
									.componentMutationRefreshed(
										componentPath: componentPath,
										authoredAttributes: refreshed,
										descendantAttributes: descendants,
										revision: mutationRevision
									)
								)
								await send(
									.setComponentParameterSucceeded(
										componentPath: componentPath,
										attributeName: parameterKey
									)
								)
							} catch {
								await send(
									.setComponentParameterFailed(error.localizedDescription)
								)
							}
						}
						.cancellable(
							id: ComponentParameterMutationCancellationID(
								componentPath: componentPath
							),
							cancelInFlight: true
						)
					}
					guard
						let spec = componentParameterAuthoringSpec(
						componentIdentifier: componentIdentifier,
						parameterKey: parameterKey,
						value: value
					)
				else {
					state.primErrorMessage =
						"Unsupported parameter mapping for \(componentIdentifier).\(parameterKey)"
					return .none
				}
				return .run { send in
					do {
						let targetPrimPath =
							if let suffix = spec.primPathSuffix {
								"\(componentPath)/\(suffix)"
							} else {
								componentPath
							}
						switch spec.operation {
						case .set(let valueLiteral):
							try DeconstructedUSDInterop.setRealityKitComponentParameter(
								url: url,
								componentPrimPath: targetPrimPath,
								attributeType: spec.attributeType,
								attributeName: spec.attributeName,
								valueLiteral: valueLiteral
							)
						case .clear:
							try DeconstructedUSDInterop.deleteRealityKitComponentParameter(
								url: url,
								componentPrimPath: targetPrimPath,
								attributeName: spec.attributeName
							)
						}
						let supplemental = supplementalComponentAuthoringSpecs(
							componentIdentifier: componentIdentifier,
							parameterKey: parameterKey,
							value: value
						)
						for extraSpec in supplemental {
							let extraTargetPrimPath =
								if let suffix = extraSpec.primPathSuffix {
									"\(componentPath)/\(suffix)"
								} else {
									componentPath
								}
							switch extraSpec.operation {
							case .set(let valueLiteral):
								try DeconstructedUSDInterop.setRealityKitComponentParameter(
									url: url,
									componentPrimPath: extraTargetPrimPath,
									attributeType: extraSpec.attributeType,
									attributeName: extraSpec.attributeName,
									valueLiteral: valueLiteral
								)
							case .clear:
								try DeconstructedUSDInterop.deleteRealityKitComponentParameter(
									url: url,
									componentPrimPath: extraTargetPrimPath,
									attributeName: extraSpec.attributeName
								)
							}
						}
						let refreshed =
							DeconstructedUSDInterop.getPrimAttributes(
								url: url,
								primPath: componentPath
							)?.authoredAttributes ?? []
						let descendants = loadComponentDescendantAttributes(
							componentPath: componentPath,
							sceneNodes: sceneNodesSnapshot,
							url: url
						)
						await send(
							.componentMutationRefreshed(
								componentPath: componentPath,
								authoredAttributes: refreshed,
								descendantAttributes: descendants,
								revision: mutationRevision
							)
						)
						await send(
							.setComponentParameterSucceeded(
								componentPath: componentPath,
								attributeName: spec.attributeName
							)
						)
					} catch {
						await send(.setComponentParameterFailed(error.localizedDescription))
					}
				}
				.cancellable(
					id: ComponentParameterMutationCancellationID(
						componentPath: componentPath
					),
					cancelInFlight: true
				)

			case .setComponentParameterSucceeded:
				state.primErrorMessage = nil
				return .none

			case .setComponentParameterFailed(let message):
				state.primErrorMessage = "Failed to set component parameter: \(message)"
				return .none

			case .addAudioLibraryResourceRequested(let componentPath, let sourceURL):
				guard let url = state.sceneURL else {
					return .none
				}
				let sceneNodesSnapshot = state.sceneNodes
				let existingResources = audioLibraryResources(
					from: state.componentDescendantAttributesByPath[componentPath] ?? []
				)
				return .run { send in
					do {
						let copied = try importAudioResource(
							sourceURL: sourceURL,
							sceneURL: url
						)
						let rootPrimPath = sceneNodesSnapshot.first?.path ?? "/Root"
						let audioFilePrimPath = uniqueAudioFilePrimPath(
							baseName: copied.resourceKey,
							rootPrimPath: rootPrimPath,
							existingTargets: existingResources.map(\.valueTarget)
						)
						let merged =
							existingResources + [
								AudioLibraryResource(
									key: copied.resourceKey,
									valueTarget: audioFilePrimPath
								)
							]
						try DeconstructedUSDInterop.setAudioLibraryResources(
							url: url,
							audioLibraryComponentPath: componentPath,
							keys: merged.map(\.key),
							valueTargets: merged.map(\.valueTarget)
						)
						try DeconstructedUSDInterop.upsertRealityKitAudioFile(
							url: url,
							primPath: audioFilePrimPath,
							relativeAssetPath: copied.relativeAssetPath,
							shouldLoop: false
						)
						let refreshed =
							DeconstructedUSDInterop.getPrimAttributes(
								url: url,
								primPath: componentPath
							)?.authoredAttributes ?? []
						await send(
							.componentAuthoredAttributesLoaded([
								componentPath: mergedComponentAuthoredAttributes(
									componentPath: componentPath,
									authoredAttributes: refreshed,
									url: url
								)
							])
						)
						await send(
							.componentDescendantAttributesLoaded([
								componentPath: loadComponentDescendantAttributes(
									componentPath: componentPath,
									sceneNodes: sceneNodesSnapshot,
									url: url
								)
							])
						)
						await send(
							.addAudioLibraryResourceSucceeded(componentPath: componentPath)
						)
					} catch {
						await send(
							.addAudioLibraryResourceFailed(error.localizedDescription)
						)
					}
				}

			case .addAudioLibraryResourceSucceeded:
				state.primErrorMessage = nil
				return .none

			case .addAudioLibraryResourceFailed(let message):
				state.primErrorMessage = "Failed to add audio resource: \(message)"
				return .none

			case .removeAudioLibraryResourceRequested(
				let componentPath,
				let resourceKey
			):
				guard let url = state.sceneURL else {
					return .none
				}
				let sceneNodesSnapshot = state.sceneNodes
				let existingResources = audioLibraryResources(
					from: state.componentDescendantAttributesByPath[componentPath] ?? []
				)
				guard
					let removalIndex = existingResources.firstIndex(where: {
						$0.key == resourceKey
					})
				else {
					state.primErrorMessage =
						"Resource '\(resourceKey)' not found in Audio Library."
					return .none
				}
				var remainingResources = existingResources
				remainingResources.remove(at: removalIndex)
				let remainingKeys = remainingResources.map(\.key)
				let remainingTargets = remainingResources.map(\.valueTarget)
				return .run { send in
					do {
						try DeconstructedUSDInterop.setAudioLibraryResources(
							url: url,
							audioLibraryComponentPath: componentPath,
							keys: remainingKeys,
							valueTargets: remainingTargets
						)
						let refreshed =
							DeconstructedUSDInterop.getPrimAttributes(
								url: url,
								primPath: componentPath
							)?.authoredAttributes ?? []
						await send(
							.componentAuthoredAttributesLoaded([
								componentPath: mergedComponentAuthoredAttributes(
									componentPath: componentPath,
									authoredAttributes: refreshed,
									url: url
								)
							])
						)
						await send(
							.componentDescendantAttributesLoaded([
								componentPath: loadComponentDescendantAttributes(
									componentPath: componentPath,
									sceneNodes: sceneNodesSnapshot,
									url: url
								)
							])
						)
						await send(
							.removeAudioLibraryResourceSucceeded(componentPath: componentPath)
						)
					} catch {
						await send(
							.removeAudioLibraryResourceFailed(error.localizedDescription)
						)
					}
				}

			case .removeAudioLibraryResourceSucceeded:
				state.primErrorMessage = nil
				return .none

			case .removeAudioLibraryResourceFailed(let message):
				state.primErrorMessage = "Failed to remove audio resource: \(message)"
				return .none

			case .addAnimationLibraryResourceRequested(
				let componentPath,
				let sourceURL
			):
				guard let url = state.sceneURL else {
					return .none
				}
				let sceneNodesSnapshot = state.sceneNodes
				let existingResources = animationLibraryResources(
					from: state.componentDescendantAttributesByPath[componentPath] ?? []
				)
				return .run { send in
					do {
						let copied = try importAnimationResource(
							sourceURL: sourceURL,
							sceneURL: url
						)
						let resourcePrimPath = uniqueAnimationLibraryResourcePrimPath(
							baseName: copied.displayName,
							componentPath: componentPath,
							existingPrimPaths: existingResources.map(\.primPath)
						)
						guard let resourcePrimName = primName(of: resourcePrimPath) else {
							throw NSError(
								domain: "InspectorFeature",
								code: 1,
								userInfo: [
									NSLocalizedDescriptionKey: "Failed to derive animation resource prim name."
								]
							)
						}
						_ = try DeconstructedUSDInterop.ensureTypedPrim(
							url: url,
							parentPrimPath: componentPath,
							typeName: "RealityKitAnimationFile",
							primName: resourcePrimName
						)
						try DeconstructedUSDInterop.setRealityKitComponentParameter(
							url: url,
							componentPrimPath: resourcePrimPath,
							attributeType: "uniform asset",
							attributeName: "file",
							valueLiteral: "@\(copied.relativeAssetPath)@"
						)
						try DeconstructedUSDInterop.setRealityKitComponentParameter(
							url: url,
							componentPrimPath: resourcePrimPath,
							attributeType: "uniform string",
							attributeName: "name",
							valueLiteral: quoteUSDString(copied.displayName)
						)
						let refreshed = DeconstructedUSDInterop.getPrimAttributes(
							url: url,
							primPath: componentPath
						)?.authoredAttributes ?? []
						await send(
							.componentAuthoredAttributesLoaded([
								componentPath: mergedComponentAuthoredAttributes(
									componentPath: componentPath,
									authoredAttributes: refreshed,
									url: url
								)
							])
						)
						await send(
							.componentDescendantAttributesLoaded([
								componentPath: loadComponentDescendantAttributes(
									componentPath: componentPath,
									sceneNodes: sceneNodesSnapshot,
									url: url
								)
							])
						)
						await send(
							.addAnimationLibraryResourceSucceeded(
								componentPath: componentPath
							)
						)
					} catch {
						await send(
							.addAnimationLibraryResourceFailed(
								error.localizedDescription
							)
						)
					}
				}

			case .addAnimationLibraryResourceSucceeded:
				state.primErrorMessage = nil
				return .none

			case .addAnimationLibraryResourceFailed(let message):
				state.primErrorMessage = "Failed to add animation resource: \(message)"
				return .none

			case .removeAnimationLibraryResourceRequested(
				let componentPath,
				let resourcePrimPath
			):
				guard let url = state.sceneURL else {
					return .none
				}
				let sceneNodesSnapshot = state.sceneNodes
				return .run { send in
					do {
						try DeconstructedUSDInterop.deletePrimAtPath(
							url: url,
							primPath: resourcePrimPath
						)
						let refreshed = DeconstructedUSDInterop.getPrimAttributes(
							url: url,
							primPath: componentPath
						)?.authoredAttributes ?? []
						await send(
							.componentAuthoredAttributesLoaded([
								componentPath: mergedComponentAuthoredAttributes(
									componentPath: componentPath,
									authoredAttributes: refreshed,
									url: url
								)
							])
						)
						await send(
							.componentDescendantAttributesLoaded([
								componentPath: loadComponentDescendantAttributes(
									componentPath: componentPath,
									sceneNodes: sceneNodesSnapshot,
									url: url
								)
							])
						)
						await send(
							.removeAnimationLibraryResourceSucceeded(
								componentPath: componentPath
							)
						)
					} catch {
						await send(
							.removeAnimationLibraryResourceFailed(
								error.localizedDescription
							)
						)
					}
				}

			case .removeAnimationLibraryResourceSucceeded:
				state.primErrorMessage = nil
				return .none

			case .removeAnimationLibraryResourceFailed(let message):
				state.primErrorMessage = "Failed to remove animation resource: \(message)"
				return .none

			case .setRawComponentAttributeRequested(
				let componentPath,
				let attributeType,
				let attributeName,
				let valueLiteral
			):
				guard let url = state.sceneURL else {
					return .none
				}
				let sceneNodesSnapshot = state.sceneNodes
				return .run { send in
					do {
						try DeconstructedUSDInterop.setRealityKitComponentParameter(
							url: url,
							componentPrimPath: componentPath,
							attributeType: attributeType,
							attributeName: attributeName,
							valueLiteral: valueLiteral
						)
						let refreshed =
							DeconstructedUSDInterop.getPrimAttributes(
								url: url,
								primPath: componentPath
							)?.authoredAttributes ?? []
						await send(
							.componentAuthoredAttributesLoaded([
								componentPath: mergedComponentAuthoredAttributes(
									componentPath: componentPath,
									authoredAttributes: refreshed,
									url: url
								)
							])
						)
						await send(
							.componentDescendantAttributesLoaded([
								componentPath: loadComponentDescendantAttributes(
									componentPath: componentPath,
									sceneNodes: sceneNodesSnapshot,
									url: url
								)
							])
						)
						await send(
							.setRawComponentAttributeSucceeded(
								componentPath: componentPath,
								attributeName: attributeName
							)
						)
					} catch {
						await send(
							.setRawComponentAttributeFailed(error.localizedDescription)
						)
					}
				}

			case .setRawComponentAttributeSucceeded:
				state.primErrorMessage = nil
				return .none

			case .setRawComponentAttributeFailed(let message):
				state.primErrorMessage = "Failed to set component attribute: \(message)"
				return .none

			case .setMeshSortingGroupDepthPassRequested(let depthPass):
				guard let url = state.sceneURL,
					let selectedPrimPath = state.selectedNodeID
				else {
					return .none
				}
				return .run { send in
					do {
						try DeconstructedUSDInterop.setRealityKitComponentParameter(
							url: url,
							componentPrimPath: selectedPrimPath,
							attributeType: "token",
							attributeName: "depthPass",
							valueLiteral: quoteUSDString(depthPass)
						)
						if let refreshed = DeconstructedUSDInterop.getPrimAttributes(
							url: url,
							primPath: selectedPrimPath
						) {
							await send(.primAttributesLoaded(refreshed))
						}
						await send(.setMeshSortingGroupDepthPassSucceeded)
					} catch {
						await send(
							.setMeshSortingGroupDepthPassFailed(error.localizedDescription)
						)
					}
				}

			case .setMeshSortingGroupDepthPassSucceeded:
				state.primErrorMessage = nil
				return .none

			case .setMeshSortingGroupDepthPassFailed(let message):
				state.primErrorMessage =
					"Failed to set model sorting group depth pass: \(message)"
				return .none

			case .deleteComponentRequested(let componentPath):
				guard let url = state.sceneURL else {
					return .none
				}
				return .run { send in
					do {
						try DeconstructedUSDInterop.deleteRealityKitComponent(
							url: url,
							componentPrimPath: componentPath
						)
						await send(.deleteComponentSucceeded(componentPath: componentPath))
					} catch {
						await send(.deleteComponentFailed(error.localizedDescription))
					}
				}

			case .deleteComponentSucceeded(let componentPath):
				state.componentActiveByPath.removeValue(forKey: componentPath)
				state.componentAuthoredAttributesByPath.removeValue(
					forKey: componentPath
				)
				state.componentDescendantAttributesByPath.removeValue(
					forKey: componentPath
				)
				state.primErrorMessage = nil
				return .none

			case .deleteComponentFailed(let message):
				state.primErrorMessage = "Failed to delete component: \(message)"
				return .none

			case .primTransformChanged(let transform):
				guard let url = state.sceneURL,
					let primPath = state.selectedNodeID
				else {
					return .none
				}
				let clock = self.clock
				state.primTransform = transform
				state.primErrorMessage = nil
				return .run { send in
					try await clock.sleep(for: .milliseconds(120))
					do {
						try DeconstructedUSDInterop.setPrimTransform(
							url: url,
							primPath: primPath,
							transform: transform
						)
						await send(.primTransformSaveSucceeded)
					} catch {
						await send(.primTransformSaveFailed(error.localizedDescription))
					}
				}
				.cancellable(
					id: PrimTransformSaveCancellationID.save,
					cancelInFlight: true
				)

			case .primTransformSaveSucceeded:
				return .none

			case .primTransformSaveFailed(let message):
				state.primErrorMessage = "Failed to save transform: \(message)"
				return .none

			case .refreshLayerData:
				guard let url = state.sceneURL else {
					return .none
				}
				state.isLoading = true
				return .run { send in
					await loadLayerData(url: url, send: send)
				}

			case .defaultPrimChanged(let primPath):
				guard let url = state.sceneURL else {
					return .none
				}
				if var layerData = state.layerData {
					layerData.defaultPrim = primPath.isEmpty ? nil : primPath
					state.layerData = layerData
				}
				return .run { send in
					do {
						try DeconstructedUSDInterop.setDefaultPrim(
							url: url,
							primPath: primPath
						)
						await send(.layerDataUpdateSucceeded)
					} catch {
						await send(.layerDataUpdateFailed(error.localizedDescription))
					}
				}

			case .metersPerUnitChanged(let value):
				guard let url = state.sceneURL else {
					return .none
				}
				if var layerData = state.layerData {
					layerData.metersPerUnit = value
					state.layerData = layerData
				}
				return .run { send in
					do {
						try DeconstructedUSDInterop.setMetersPerUnit(url: url, value: value)
						await send(.layerDataUpdateSucceeded)
					} catch {
						await send(.layerDataUpdateFailed(error.localizedDescription))
					}
				}

			case .upAxisChanged(let axis):
				guard let url = state.sceneURL else {
					return .none
				}
				if var layerData = state.layerData {
					layerData.upAxis = axis
					state.layerData = layerData
				}
				return .run { send in
					do {
						try DeconstructedUSDInterop.setUpAxis(url: url, axis: axis.rawValue)
						await send(.layerDataUpdateSucceeded)
					} catch {
						await send(.layerDataUpdateFailed(error.localizedDescription))
					}
				}

			case .convertVariantsToConfigurationsTapped:
				return .none

			case .layerDataUpdateSucceeded:
				return .none

			case .layerDataUpdateFailed(let message):
				state.errorMessage = message
				return .none

			case .playbackPlayPauseTapped:
				guard let playbackData = state.playbackData,
					playbackData.hasTimeline
				else {
					return .none
				}
				state.playbackIsPlaying.toggle()
				state.playbackIsScrubbing = false
				if state.playbackIsPlaying {
					return startPlaybackTimer(state: state, clock: clock)
				}
				return .cancel(id: PlaybackTimerID.playback)

			case .playbackStopTapped:
				state.playbackIsPlaying = false
				state.playbackIsScrubbing = false
				if let playbackData = state.playbackData {
					state.playbackCurrentTime = playbackData.startTimeCode
				} else {
					state.playbackCurrentTime = 0
				}
				return .cancel(id: PlaybackTimerID.playback)

			case .playbackScrubbed(let value, let isEditing):
				state.playbackCurrentTime = value
				state.playbackIsScrubbing = isEditing
				if isEditing {
					state.playbackIsPlaying = false
					return .cancel(id: PlaybackTimerID.playback)
				}
				return .none

			case .playbackTick:
				guard let playbackData = state.playbackData,
					playbackData.hasTimeline,
					state.playbackIsPlaying
				else {
					return .cancel(id: PlaybackTimerID.playback)
				}
				let fps =
					playbackData.timeCodesPerSecond > 0
					? playbackData.timeCodesPerSecond
					: 24.0
				let delta = (1.0 / fps) * state.playbackSpeed
				let nextTime = state.playbackCurrentTime + delta
				if nextTime >= playbackData.endTimeCode {
					if shouldLoop(playbackData.playbackMode) {
						state.playbackCurrentTime = playbackData.startTimeCode
						return .none
					}
					state.playbackCurrentTime = playbackData.endTimeCode
					state.playbackIsPlaying = false
					return .cancel(id: PlaybackTimerID.playback)
				}
				state.playbackCurrentTime = nextTime
				return .none
			}
		}
	}
}

private func loadLayerData(url: URL, send: Send<InspectorFeature.Action>) async
{
	print(
		"[InspectorFeature] loadLayerData starting for: \(url.lastPathComponent)"
	)
	let metadata = DeconstructedUSDInterop.getStageMetadata(url: url)
	print(
		"[InspectorFeature] Got metadata: defaultPrim=\(metadata.defaultPrimName ?? "nil"), mpu=\(metadata.metersPerUnit?.description ?? "nil"), upAxis=\(metadata.upAxis ?? "nil")"
	)

	let upAxis: UpAxis
	if let axisString = metadata.upAxis,
		let axis = UpAxis(rawValue: axisString)
	{
		upAxis = axis
	} else {
		upAxis = .y
	}

	let layerData = SceneLayerData(
		defaultPrim: metadata.defaultPrimName,
		metersPerUnit: metadata.metersPerUnit ?? 1.0,
		upAxis: upAxis,
		availablePrims: metadata.defaultPrimName.map { [$0] } ?? []
	)

	let playbackData = ScenePlaybackData(
		startTimeCode: metadata.startTimeCode ?? 0,
		endTimeCode: metadata.endTimeCode ?? 0,
		timeCodesPerSecond: metadata.timeCodesPerSecond ?? 24,
		autoPlay: metadata.autoPlay,
		playbackMode: metadata.playbackMode,
		animationTracks: metadata.animationTracks
	)

	print("[InspectorFeature] Sending sceneMetadataLoaded")
	await send(.sceneMetadataLoaded(layerData, playbackData))
}

private func extractAvailablePrims(from nodes: [SceneNode]) -> [String] {
	var prims: [String] = []
	for node in nodes {
		prims.append(node.name)
		prims.append(
			contentsOf: collectPrimPaths(from: node.children, parentPath: node.name)
		)
	}
	return prims
}

private func collectPrimPaths(from nodes: [SceneNode], parentPath: String)
	-> [String]
{
	var paths: [String] = []
	for node in nodes {
		let fullPath = "\(parentPath)/\(node.name)"
		paths.append(fullPath)
		paths.append(
			contentsOf: collectPrimPaths(from: node.children, parentPath: fullPath)
		)
	}
	return paths
}

private func findNode(id: SceneNode.ID, in nodes: [SceneNode]) -> SceneNode? {
	for node in nodes {
		if node.id == id {
			return node
		}
		if let found = findNode(id: id, in: node.children) {
			return found
		}
	}
	return nil
}

private func updateBoundMaterial(state: inout InspectorFeature.State) {
	guard let binding = normalizeMaterialPath(state.primMaterialBinding) else {
		state.boundMaterial = nil
		return
	}
	state.boundMaterial = state.availableMaterials.first {
		normalizeMaterialPath($0.path) == binding
	}
}

private func normalizeMaterialPath(_ path: String?) -> String? {
	guard var path, !path.isEmpty else { return nil }
	path = path.trimmingCharacters(in: .whitespacesAndNewlines)
	guard !path.isEmpty else { return nil }
	// USD relationship targets are often serialized as </Prim/Material>.
	if path.first == "<", path.last == ">", path.count >= 2 {
		path.removeFirst()
		path.removeLast()
	}
	return path.isEmpty ? nil : path
}

private func resolvedVariantScopePrimPath(
	from selectedPrimPath: String,
	url: URL
) -> String {
	var currentPath = selectedPrimPath
	while true {
		// If the currently selected prim has its own variant sets (e.g. realistic -> lods),
		// keep it as the inspector scope and do not walk up to parent set owners.
		if let currentSets = try? DeconstructedUSDInterop.listPrimVariantSets(
			url: url,
			primPath: currentPath
		),
			!currentSets.isEmpty
		{
			return currentPath
		}

		guard let parentPath = parentPrimPath(of: currentPath) else {
			return currentPath
		}
		let childName = String(currentPath.split(separator: "/").last ?? "")
		guard !childName.isEmpty else {
			return currentPath
		}
		guard
			let parentSets = try? DeconstructedUSDInterop.listPrimVariantSets(
				url: url,
				primPath: parentPath
			)
		else {
			return currentPath
		}
		let isVariantOption = parentSets.contains { set in
			set.options.contains {
				$0.id == childName || $0.displayName == childName
			}
		}
		guard isVariantOption else {
			return currentPath
		}
		currentPath = parentPath
	}
}

private func loadComponentActivationState(
	selectedPrimPath: String,
	sceneNodes: [SceneNode],
	url: URL
) -> [String: Bool] {
	let parsedComponents = DeconstructedUSDInterop.listRealityKitComponentPrims(
		url: url,
		parentPrimPath: selectedPrimPath
	)
	if !parsedComponents.isEmpty {
		return Dictionary(
			uniqueKeysWithValues: parsedComponents.map { ($0.path, $0.isActive) }
		)
	}

	guard let selectedNode = findNode(id: selectedPrimPath, in: sceneNodes) else {
		return [:]
	}
	let componentNodes = selectedNode.children.filter {
		$0.typeName == "RealityKitComponent"
			|| $0.typeName == "RealityKitCustomComponent"
			|| InspectorComponentCatalog.definition(forAuthoredPrimName: $0.name)
				!= nil
	}
	guard !componentNodes.isEmpty else {
		return [:]
	}
	var states: [String: Bool] = [:]
	for component in componentNodes {
		let isActive =
			DeconstructedUSDInterop.getPrimAttributes(
				url: url,
				primPath: component.path
			)?.isActive ?? true
		states[component.path] = isActive
	}
	return states
}

public struct ComponentDescendantAttributes: Equatable, Sendable {
	public let primPath: String
	public let displayName: String
	public let authoredAttributes: [USDPrimAttributes.AuthoredAttribute]

	public init(
		primPath: String,
		displayName: String,
		authoredAttributes: [USDPrimAttributes.AuthoredAttribute]
	) {
		self.primPath = primPath
		self.displayName = displayName
		self.authoredAttributes = authoredAttributes
	}
}

public struct AudioLibraryResource: Equatable, Sendable {
	public let key: String
	public let valueTarget: String

	public init(key: String, valueTarget: String) {
		self.key = key
		self.valueTarget = valueTarget
	}
}

public struct AnimationLibraryResource: Equatable, Sendable {
	public let primPath: String
	public let displayName: String
	public let relativeAssetPath: String

	public init(primPath: String, displayName: String, relativeAssetPath: String) {
		self.primPath = primPath
		self.displayName = displayName
		self.relativeAssetPath = relativeAssetPath
	}
}

private func loadComponentDescendantAttributes(
	componentPath: String,
	sceneNodes: [SceneNode],
	url: URL
) -> [ComponentDescendantAttributes] {
	guard let componentNode = findNode(id: componentPath, in: sceneNodes) else {
		return []
	}
	let componentAttributes =
		DeconstructedUSDInterop.getPrimAttributes(
			url: url,
			primPath: componentPath
		)?.authoredAttributes ?? []
	let componentID = componentIdentifier(from: componentAttributes)
	let descendants = flattenedDescendants(of: componentNode)
	guard !descendants.isEmpty || componentID == "RCP.BehaviorsContainer" else {
		return []
	}
	var collected: [ComponentDescendantAttributes] = []
	for descendant in descendants {
		let attrs =
			DeconstructedUSDInterop.getPrimAttributes(
				url: url,
				primPath: descendant.path
			)?.authoredAttributes ?? []
		guard !attrs.isEmpty else { continue }
		collected.append(
			ComponentDescendantAttributes(
				primPath: descendant.path,
				displayName: descendant.name,
				authoredAttributes: attrs
			)
		)
	}
	if componentID == "RCP.BehaviorsContainer" {
		let behaviorTargets = parseUSDRelationshipTargets(
			authoredLiteral(in: componentAttributes, names: ["behaviors"])
		)
		var seenPaths = Set(collected.map(\.primPath))
		for target in behaviorTargets where !target.isEmpty {
			guard let behaviorNode = findNode(id: target, in: sceneNodes) else {
				continue
			}
			let behaviorNodes = [behaviorNode] + flattenedDescendants(of: behaviorNode)
			for node in behaviorNodes where !seenPaths.contains(node.path) {
				let attrs =
					DeconstructedUSDInterop.getPrimAttributes(
						url: url,
						primPath: node.path
					)?.authoredAttributes ?? []
				let finalAttrs: [USDPrimAttributes.AuthoredAttribute]
				if attrs.isEmpty {
					finalAttrs = [
						USDPrimAttributes.AuthoredAttribute(
							name: "path",
							value: quoteUSDString(node.path)
						)
					]
				} else {
					finalAttrs = attrs
				}
				seenPaths.insert(node.path)
				collected.append(
					ComponentDescendantAttributes(
						primPath: node.path,
						displayName: node.name,
						authoredAttributes: finalAttrs
					)
				)
			}
		}
	}
	let resourcesPath = "\(componentPath)/resources"
	if !collected.contains(where: { $0.primPath == resourcesPath }) {
		let resourcesAttributes =
			DeconstructedUSDInterop.getPrimAttributes(
				url: url,
				primPath: resourcesPath
			)?.authoredAttributes ?? []
		if !resourcesAttributes.isEmpty {
			collected.append(
				ComponentDescendantAttributes(
					primPath: resourcesPath,
					displayName: "resources",
					authoredAttributes: resourcesAttributes
				)
			)
		}
	}
	return collected
}

private func loadMeshSortingGroupMembers(
	selectedPrimPath: String,
	sceneNodes: [SceneNode],
	url: URL
) -> [String] {
	guard let selectedNode = findNode(id: selectedPrimPath, in: sceneNodes),
		selectedNode.typeName == "RealityKitMeshSortingGroup"
	else {
		return []
	}
	let primPaths = allNodePaths(in: sceneNodes)
	var members: [String] = []
	for primPath in primPaths {
		let components = DeconstructedUSDInterop.listRealityKitComponentPrims(
			url: url,
			parentPrimPath: primPath
		)
		for component in components where component.primName == "MeshSorting" {
			let attrs =
				DeconstructedUSDInterop.getPrimAttributes(
					url: url,
					primPath: component.path
				)?.authoredAttributes ?? []
			let groupPath = meshSortingGroupPath(from: attrs)
			if groupPath == selectedPrimPath {
				members.append(primPath)
			}
		}
	}
	return Array(Set(members)).sorted()
}

private func allNodePaths(in nodes: [SceneNode]) -> [String] {
	var result: [String] = []
	for node in nodes {
		result.append(node.path)
		result.append(contentsOf: allNodePaths(in: node.children))
	}
	return result
}

private func flattenedDescendants(of node: SceneNode) -> [SceneNode] {
	var result: [SceneNode] = []
	for child in node.children {
		result.append(child)
		result.append(contentsOf: flattenedDescendants(of: child))
	}
	return result
}

private func mergedComponentAuthoredAttributes(
	componentPath: String,
	authoredAttributes: [USDPrimAttributes.AuthoredAttribute],
	url: URL
) -> [USDPrimAttributes.AuthoredAttribute] {
	guard
		componentIdentifier(from: authoredAttributes) == "RealityKit.MeshSorting"
	else {
		return authoredAttributes
	}
	guard let groupPath = meshSortingGroupPath(from: authoredAttributes),
		let groupAttributes = DeconstructedUSDInterop.getPrimAttributes(
			url: url,
			primPath: groupPath
		)?.authoredAttributes
	else {
		return authoredAttributes
	}

	var merged = authoredAttributes
	for groupAttr in groupAttributes where groupAttr.name == "depthPass" {
		merged.removeAll { $0.name == groupAttr.name }
		merged.append(groupAttr)
	}
	return merged
}

private func componentIdentifier(
	from authoredAttributes: [USDPrimAttributes.AuthoredAttribute]
) -> String? {
	authoredAttributes
		.first(where: { $0.name == "info:id" })?
		.value
		.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
}

private func meshSortingGroupPath(
	from authoredAttributes: [USDPrimAttributes.AuthoredAttribute]
) -> String? {
	guard let raw = authoredAttributes.first(where: { $0.name == "group" })?.value
	else {
		return nil
	}
	return parseUSDRelationshipTarget(raw)
}

private func parseUSDRelationshipTarget(_ raw: String) -> String {
	let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
	if trimmed.hasPrefix("<"), trimmed.hasSuffix(">"), trimmed.count >= 2 {
		return String(trimmed.dropFirst().dropLast())
	}
	return trimmed
}

private struct ImportedAudioResource: Sendable, Equatable {
	let resourceKey: String
	let relativeAssetPath: String
}

private struct ImportedAnimationResource: Sendable, Equatable {
	let displayName: String
	let relativeAssetPath: String
}

private func audioLibraryResources(
	from descendantAttributes: [ComponentDescendantAttributes]
) -> [AudioLibraryResource] {
	guard
		let resourcesNode = descendantAttributes.first(where: {
			$0.displayName == "resources"
				|| $0.displayName.lowercased().contains("resources")
				|| $0.primPath.hasSuffix("/resources")
		})
	else {
		return []
	}
	let attrs = resourcesNode.authoredAttributes
	let keysLiteral = authoredLiteral(in: attrs, names: ["keys"])
	let valuesLiteral = authoredLiteral(in: attrs, names: ["values"])
	let keys = parseUSDStringArray(keysLiteral)
	let values = parseUSDRelationshipTargets(valuesLiteral)
	guard !keys.isEmpty else { return [] }
	return keys.enumerated().map { index, key in
		let valueTarget = index < values.count ? values[index] : ""
		return AudioLibraryResource(key: key, valueTarget: valueTarget)
	}
}

#if DEBUG
func testAudioLibraryResources(
	from descendantAttributes: [ComponentDescendantAttributes]
) -> [AudioLibraryResource] {
	audioLibraryResources(from: descendantAttributes)
}
#endif

private func animationLibraryResources(
	from descendantAttributes: [ComponentDescendantAttributes]
) -> [AnimationLibraryResource] {
	descendantAttributes.compactMap { descendant in
		let fileLiteral = authoredLiteral(
			in: descendant.authoredAttributes,
			names: ["file"]
		)
		guard !fileLiteral.isEmpty else { return nil }
		let displayName =
			parseUSDStringToken(
				authoredLiteral(
					in: descendant.authoredAttributes,
					names: ["name"],
					allowLooseMatch: false
				)
			)
		let relativeAssetPath = parseUSDAssetPath(fileLiteral)
		return AnimationLibraryResource(
			primPath: descendant.primPath,
			displayName: displayName.isEmpty ? descendant.displayName : displayName,
			relativeAssetPath: relativeAssetPath
		)
	}
	.sorted {
		$0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
	}
}

private func authoredLiteral(
	in attributes: [USDPrimAttributes.AuthoredAttribute],
	names: [String],
	allowLooseMatch: Bool = true
) -> String {
	let lowered = Set(names.map { $0.lowercased() })
	if let exact = attributes.first(where: {
		lowered.contains($0.name.lowercased())
	}) {
		return exact.value
	}
	if let typed = attributes.first(where: { attribute in
		let key = attribute.name.lowercased()
		return lowered.contains(where: { key.hasSuffix(" \($0)") })
	}) {
		return typed.value
	}
	if allowLooseMatch, let loose = attributes.first(where: { attribute in
		let key = attribute.name.lowercased()
		return lowered.contains(where: { key.contains($0) })
	}) {
		return loose.value
	}
	return ""
}

private func parseUSDStringArray(_ raw: String) -> [String] {
	let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
	guard !trimmed.isEmpty else { return [] }
	if trimmed.hasPrefix("["), trimmed.hasSuffix("]"), trimmed.count >= 2 {
		let body = String(trimmed.dropFirst().dropLast())
		let parts = body.split(separator: ",", omittingEmptySubsequences: true)
		return parts.map {
			parseUSDStringToken(
				String($0).trimmingCharacters(in: .whitespacesAndNewlines)
			)
		}
	}
	if trimmed.hasPrefix("("), trimmed.hasSuffix(")"), trimmed.count >= 2 {
		let body = String(trimmed.dropFirst().dropLast())
		let parts = body.split(separator: ",", omittingEmptySubsequences: true)
		return parts.map {
			parseUSDStringToken(
				String($0).trimmingCharacters(in: .whitespacesAndNewlines)
			)
		}
	}
	return [parseUSDStringToken(trimmed)]
}

private func parseUSDStringToken(_ token: String) -> String {
	guard token.count >= 2, token.first == "\"", token.last == "\"" else {
		return token
	}
	let start = token.index(after: token.startIndex)
	let end = token.index(before: token.endIndex)
	return String(token[start..<end])
		.replacingOccurrences(of: "\\\"", with: "\"")
		.replacingOccurrences(of: "\\\\", with: "\\")
}

private func parseUSDAssetPath(_ raw: String) -> String {
	let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
	guard trimmed.count >= 2, trimmed.first == "@", trimmed.last == "@"
	else {
		return trimmed
	}
	let start = trimmed.index(after: trimmed.startIndex)
	let end = trimmed.index(before: trimmed.endIndex)
	return String(trimmed[start..<end])
}

private func parseUSDRelationshipTargets(_ raw: String) -> [String] {
	let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
	if trimmed.hasPrefix("["), trimmed.hasSuffix("]"), trimmed.count >= 2 {
		let body = String(trimmed.dropFirst().dropLast())
		return
			body
			.split(separator: ",", omittingEmptySubsequences: true)
			.map { parseUSDRelationshipTarget(String($0)) }
			.filter { !$0.isEmpty }
	}
	let single = parseUSDRelationshipTarget(trimmed)
	return single.isEmpty ? [] : [single]
}

private func normalizedAudioLibraryDescendants(
	componentPath: String,
	descendantAttributes: [ComponentDescendantAttributes],
	componentAuthoredAttributes: [USDPrimAttributes.AuthoredAttribute]
) -> [ComponentDescendantAttributes] {
	guard
		componentIdentifier(from: componentAuthoredAttributes)
			== "RealityKit.AudioLibrary"
	else {
		return descendantAttributes
	}
	let hasResourcesNode = descendantAttributes.contains {
		$0.displayName == "resources"
			|| $0.displayName.lowercased().contains("resources")
			|| $0.primPath.hasSuffix("/resources")
	}
	guard !hasResourcesNode else { return descendantAttributes }
	let keysLiteral = authoredLiteral(
		in: componentAuthoredAttributes,
		names: ["keys"]
	)
	let valuesLiteral = authoredLiteral(
		in: componentAuthoredAttributes,
		names: ["values"]
	)
	guard !keysLiteral.isEmpty || !valuesLiteral.isEmpty else {
		return descendantAttributes
	}
	var synthesized: [USDPrimAttributes.AuthoredAttribute] = []
	if !keysLiteral.isEmpty {
		synthesized.append(.init(name: "keys", value: keysLiteral))
	}
	if !valuesLiteral.isEmpty {
		synthesized.append(.init(name: "values", value: valuesLiteral))
	}
	guard !synthesized.isEmpty else { return descendantAttributes }
	var result = descendantAttributes
	result.append(
		ComponentDescendantAttributes(
			primPath: "\(componentPath)/resources",
			displayName: "resources",
			authoredAttributes: synthesized
		)
	)
	return result
}

private func importAudioResource(
	sourceURL: URL,
	sceneURL: URL
) throws -> ImportedAudioResource {
	let copied = try importResourceFile(sourceURL: sourceURL, sceneURL: sceneURL)
	return ImportedAudioResource(
		resourceKey: copied.destinationURL.lastPathComponent,
		relativeAssetPath: copied.relativeAssetPath
	)
}

private func importAnimationResource(
	sourceURL: URL,
	sceneURL: URL
) throws -> ImportedAnimationResource {
	let copied = try importResourceFile(sourceURL: sourceURL, sceneURL: sceneURL)
	return ImportedAnimationResource(
		displayName: sourceURL.deletingPathExtension().lastPathComponent,
		relativeAssetPath: copied.relativeAssetPath
	)
}

private struct ImportedResourceFile: Sendable, Equatable {
	let destinationURL: URL
	let relativeAssetPath: String
}

private func importResourceFile(
	sourceURL: URL,
	sceneURL: URL
) throws -> ImportedResourceFile {
	let fileManager = FileManager.default
	guard let rkassetsURL = resolveRKAssetsRoot(for: sceneURL) else {
		throw NSError(
			domain: "InspectorFeature",
			code: 1,
			userInfo: [
				NSLocalizedDescriptionKey: "Unable to resolve .rkassets root for scene."
			]
		)
	}
	var destinationURL = rkassetsURL.appendingPathComponent(
		sourceURL.lastPathComponent
	)
	if fileManager.fileExists(atPath: destinationURL.path) {
		let stem = sourceURL.deletingPathExtension().lastPathComponent
		let ext = sourceURL.pathExtension
		var index = 2
		while fileManager.fileExists(atPath: destinationURL.path) {
			let candidate = "\(stem)-\(index)"
			let filename = ext.isEmpty ? candidate : "\(candidate).\(ext)"
			destinationURL = rkassetsURL.appendingPathComponent(filename)
			index += 1
		}
	}
	try fileManager.copyItem(at: sourceURL, to: destinationURL)
	let relativePath = relativePathFromSceneDirectory(
		sceneURL: sceneURL,
		targetURL: destinationURL
	)
	return ImportedResourceFile(
		destinationURL: destinationURL,
		relativeAssetPath: relativePath
	)
}

private func resolveRKAssetsRoot(for sceneURL: URL) -> URL? {
	var current = sceneURL.deletingLastPathComponent()
	while current.path != "/" {
		if current.pathExtension.lowercased() == "rkassets" {
			return current
		}
		current = current.deletingLastPathComponent()
	}
	return nil
}

private func relativePathFromSceneDirectory(sceneURL: URL, targetURL: URL)
	-> String
{
	let baseComponents = sceneURL.deletingLastPathComponent().standardizedFileURL
		.pathComponents
	let targetComponents = targetURL.standardizedFileURL.pathComponents
	var common = 0
	while common < baseComponents.count,
		common < targetComponents.count,
		baseComponents[common] == targetComponents[common]
	{
		common += 1
	}
	let upCount = max(0, baseComponents.count - common)
	let upParts = Array(repeating: "..", count: upCount)
	let downParts = Array(targetComponents.dropFirst(common))
	let parts = upParts + downParts
	return parts.isEmpty ? "." : parts.joined(separator: "/")
}

private func uniqueAudioFilePrimPath(
	baseName: String,
	rootPrimPath: String,
	existingTargets: [String]
) -> String {
	let sanitized = sanitizeAudioFilePrimName(baseName)
	var candidate = "\(rootPrimPath)/\(sanitized)"
	var index = 2
	let existing = Set(existingTargets)
	while existing.contains(candidate) {
		candidate = "\(rootPrimPath)/\(sanitized)_\(index)"
		index += 1
	}
	return candidate
}

private func uniqueAnimationLibraryResourcePrimPath(
	baseName: String,
	componentPath: String,
	existingPrimPaths: [String]
) -> String {
	let sanitized = sanitizeAnimationLibraryPrimName(baseName)
	var candidate = "\(componentPath)/\(sanitized)"
	var index = 2
	let existing = Set(existingPrimPaths)
	while existing.contains(candidate) {
		candidate = "\(componentPath)/\(sanitized)_\(index)"
		index += 1
	}
	return candidate
}

private func sanitizeAudioFilePrimName(_ key: String) -> String {
	let base =
		key
		.replacingOccurrences(of: ".", with: "_")
		.replacingOccurrences(of: "-", with: "_")
	let filtered = base.map { char -> Character in
		let isValid = char.unicodeScalars.allSatisfy {
			CharacterSet.alphanumerics.contains($0) || $0 == "_"
		}
		if isValid {
			return char
		}
		return "_"
	}
	var name = String(filtered)
	if let first = name.unicodeScalars.first,
		CharacterSet.decimalDigits.contains(first)
	{
		name = "_" + name
	}
	return name.isEmpty ? "_audio" : name
}

private func sanitizeAnimationLibraryPrimName(_ value: String) -> String {
	let filtered = value.map { char -> Character in
		let isValid = char.unicodeScalars.allSatisfy {
			CharacterSet.alphanumerics.contains($0) || $0 == "_"
		}
		return isValid ? char : "_"
	}
	var name = String(filtered)
	if let first = name.unicodeScalars.first,
	   CharacterSet.decimalDigits.contains(first)
	{
		name = "_" + name
	}
	return name.isEmpty ? "_animation" : name
}

private func applyMeshSortingParameterChange(
	url: URL,
	componentPath: String,
	parameterKey: String,
	value: InspectorComponentParameterValue
) throws {
	switch (parameterKey, value) {
	case ("group", .string(let input)):
		let normalized = normalizedMeshSortingGroupPath(input)
		if let groupPath = normalized {
			_ = try DeconstructedUSDInterop.ensureRealityKitMeshSortingGroup(
				url: url,
				groupPrimPath: groupPath
			)
			try DeconstructedUSDInterop.setRealityKitComponentParameter(
				url: url,
				componentPrimPath: componentPath,
				attributeType: "rel",
				attributeName: "group",
				valueLiteral: "<\(groupPath)>"
			)
		} else {
			try DeconstructedUSDInterop.deleteRealityKitComponentParameter(
				url: url,
				componentPrimPath: componentPath,
				attributeName: "group"
			)
		}
	case ("priorityInGroup", .double(let number)):
		try DeconstructedUSDInterop.setRealityKitComponentParameter(
			url: url,
			componentPrimPath: componentPath,
			attributeType: "int",
			attributeName: "priorityInGroup",
			valueLiteral: String(Int(number.rounded()))
		)
	case ("depthPass", .string(let selected)):
		let componentAttrs =
			DeconstructedUSDInterop.getPrimAttributes(
				url: url,
				primPath: componentPath
			)?.authoredAttributes ?? []
		let existingGroup = meshSortingGroupPath(from: componentAttrs)
		let groupPath = existingGroup ?? "/Root/Model_Sorting_Group"
		_ = try DeconstructedUSDInterop.ensureRealityKitMeshSortingGroup(
			url: url,
			groupPrimPath: groupPath
		)
		if existingGroup == nil {
			try DeconstructedUSDInterop.setRealityKitComponentParameter(
				url: url,
				componentPrimPath: componentPath,
				attributeType: "rel",
				attributeName: "group",
				valueLiteral: "<\(groupPath)>"
			)
		}
		try DeconstructedUSDInterop.setRealityKitComponentParameter(
			url: url,
			componentPrimPath: groupPath,
			attributeType: "token",
			attributeName: "depthPass",
			valueLiteral: quoteUSDString(selected)
		)
	default:
		throw NSError(
			domain: "InspectorFeature",
			code: 1,
			userInfo: [
				NSLocalizedDescriptionKey:
					"Unsupported MeshSorting parameter: \(parameterKey)"
			]
		)
	}
}

private func applyCharacterControllerParameterChange(
	url: URL,
	componentPath: String,
	parameterKey: String,
	value: InspectorComponentParameterValue
) throws -> USDTransformData? {
	let controllerPath = "\(componentPath)/m_controllerDesc"
	let collisionFilterPath = "\(controllerPath)/collisionFilter"
	_ = try DeconstructedUSDInterop.ensureTypedPrim(
		url: url,
		parentPrimPath: componentPath,
		typeName: "RealityKitStruct",
		primName: "m_controllerDesc"
	)
	_ = try DeconstructedUSDInterop.ensureTypedPrim(
		url: url,
		parentPrimPath: controllerPath,
		typeName: "RealityKitStruct",
		primName: "collisionFilter"
	)

	switch (parameterKey, value) {
	case ("height", .double(let valueCM)):
		var extents = currentCharacterControllerExtents(url: url, controllerPath: controllerPath)
		extents.x = max(0, valueCM) / 100.0
		try setCharacterControllerExtents(url: url, controllerPath: controllerPath, extents: extents)
		return nil
	case ("radius", .double(let valueCM)):
		var extents = currentCharacterControllerExtents(url: url, controllerPath: controllerPath)
		extents.y = max(0, valueCM) / 100.0
		try setCharacterControllerExtents(url: url, controllerPath: controllerPath, extents: extents)
		return nil
	case ("skinWidth", .double(let valueCM)):
		let valueMeters = max(0, valueCM) / 100.0
		try DeconstructedUSDInterop.setRealityKitComponentParameter(
			url: url,
			componentPrimPath: controllerPath,
			attributeType: "float",
			attributeName: "skinWidth",
			valueLiteral: formatUSDFloat(valueMeters)
		)
		return nil
	case ("stepLimit", .double(let valueCM)):
		let valueMeters = max(0, valueCM) / 100.0
		try DeconstructedUSDInterop.setRealityKitComponentParameter(
			url: url,
			componentPrimPath: controllerPath,
			attributeType: "float",
			attributeName: "stepLimit",
			valueLiteral: formatUSDFloat(valueMeters)
		)
		return nil
	case ("slopeLimit", .double(let valueDegrees)):
		let radians = max(0, valueDegrees) * .pi / 180.0
		try DeconstructedUSDInterop.setRealityKitComponentParameter(
			url: url,
			componentPrimPath: controllerPath,
			attributeType: "float",
			attributeName: "slopeLimit",
			valueLiteral: formatUSDFloat(radians)
		)
		return nil
	case ("group", .string(let value)):
		if value == "Default" {
			try DeconstructedUSDInterop.deleteRealityKitComponentParameter(
				url: url,
				componentPrimPath: collisionFilterPath,
				attributeName: "group"
			)
		} else if value == "All" {
			try DeconstructedUSDInterop.setRealityKitComponentParameter(
				url: url,
				componentPrimPath: collisionFilterPath,
				attributeType: "uint",
				attributeName: "group",
				valueLiteral: "4294967295"
			)
		}
		return nil
	case ("mask", .string(let value)):
		if value == "Default" {
			try DeconstructedUSDInterop.deleteRealityKitComponentParameter(
				url: url,
				componentPrimPath: collisionFilterPath,
				attributeName: "mask"
			)
		} else if value == "All" {
			try DeconstructedUSDInterop.setRealityKitComponentParameter(
				url: url,
				componentPrimPath: collisionFilterPath,
				attributeType: "uint",
				attributeName: "mask",
				valueLiteral: "4294967295"
			)
		}
		return nil
	case ("upVector", .string(let rawVector)):
		guard let parentPath = parentPrimPath(of: componentPath),
			  var transform = DeconstructedUSDInterop.getPrimTransform(url: url, primPath: parentPath),
			  let targetUp = parseDirectionVector3(rawVector)
		else {
			throw NSError(
				domain: "InspectorFeature",
				code: 1,
				userInfo: [
					NSLocalizedDescriptionKey: "Failed to parse Up Vector or resolve prim transform."
				]
			)
		}
		transform.rotationDegrees = rotationDegreesAligningYAxis(to: targetUp)
		try DeconstructedUSDInterop.setPrimTransform(
			url: url,
			primPath: parentPath,
			transform: transform
		)
		return transform
	default:
		throw NSError(
			domain: "InspectorFeature",
			code: 1,
			userInfo: [
				NSLocalizedDescriptionKey:
					"Unsupported Character Controller parameter: \(parameterKey)"
			]
		)
	}
}

private func currentCharacterControllerExtents(
	url: URL,
	controllerPath: String
) -> SIMD3<Double> {
	let attrs = DeconstructedUSDInterop.getPrimAttributes(
		url: url,
		primPath: controllerPath
	)?.authoredAttributes ?? []
	let literal = authoredLiteral(in: attrs, names: ["extents"])
	return parseVector3Components(literal) ?? SIMD3<Double>(0, 0, 0)
}

private func setCharacterControllerExtents(
	url: URL,
	controllerPath: String,
	extents: SIMD3<Double>
) throws {
	try DeconstructedUSDInterop.setRealityKitComponentParameter(
		url: url,
		componentPrimPath: controllerPath,
		attributeType: "float3",
		attributeName: "extents",
		valueLiteral: formatUSDFloat3Literal(extents)
	)
}

private struct AnchoringDescriptorState {
	var target: String
	var positionMeters: SIMD3<Double>
	var orientationDegrees: SIMD3<Double>
	var scale: SIMD3<Double>
	var hasTransform: Bool
}

private func applyAnchoringParameterChange(
	url: URL,
	componentPath: String,
	parameterKey: String,
	value: InspectorComponentParameterValue
) throws {
	let descriptorPath = "\(componentPath)/descriptor"
	_ = try DeconstructedUSDInterop.ensureTypedPrim(
		url: url,
		parentPrimPath: componentPath,
		typeName: "RealityKitStruct",
		primName: "descriptor"
	)

	var state = loadAnchoringDescriptorState(url: url, descriptorPath: descriptorPath)
	var shouldWriteTransform = state.hasTransform
	switch (parameterKey, value) {
	case ("target", .string(let target)):
		let canonical = canonicalAnchoringTarget(target)
		state.target = canonical
		if canonical == "World" {
			try DeconstructedUSDInterop.deleteRealityKitComponentParameter(
				url: url,
				componentPrimPath: descriptorPath,
				attributeName: "type"
			)
		} else {
			try DeconstructedUSDInterop.setRealityKitComponentParameter(
				url: url,
				componentPrimPath: descriptorPath,
				attributeType: "token",
				attributeName: "type",
				valueLiteral: quoteUSDString(canonical)
			)
		}
	case ("position", .string(let rawVector)):
		guard let positionCM = parseVector3Components(rawVector) else {
			throw NSError(
				domain: "InspectorFeature",
				code: 1,
				userInfo: [NSLocalizedDescriptionKey: "Invalid anchoring position format."]
			)
		}
		state.positionMeters = positionCM / 100.0
		shouldWriteTransform = true
	case ("orientation", .string(let rawVector)):
		guard let orientation = parseVector3Components(rawVector) else {
			throw NSError(
				domain: "InspectorFeature",
				code: 1,
				userInfo: [NSLocalizedDescriptionKey: "Invalid anchoring orientation format."]
			)
		}
		state.orientationDegrees = orientation
		shouldWriteTransform = true
	case ("scale", .string(let rawVector)):
		guard let scale = parseVector3Components(rawVector) else {
			throw NSError(
				domain: "InspectorFeature",
				code: 1,
				userInfo: [NSLocalizedDescriptionKey: "Invalid anchoring scale format."]
			)
		}
		state.scale = SIMD3<Double>(
			max(0.000_001, scale.x),
			max(0.000_001, scale.y),
			max(0.000_001, scale.z)
		)
		shouldWriteTransform = true
	default:
		throw NSError(
			domain: "InspectorFeature",
			code: 1,
			userInfo: [
				NSLocalizedDescriptionKey:
					"Unsupported Anchoring parameter: \(parameterKey)"
			]
		)
	}

	if shouldWriteTransform {
		try DeconstructedUSDInterop.setRealityKitComponentParameter(
			url: url,
			componentPrimPath: descriptorPath,
			attributeType: "matrix4d",
			attributeName: "transform",
			valueLiteral: anchoringMatrixLiteral(
				positionMeters: state.positionMeters,
				orientationDegrees: state.orientationDegrees,
				scale: state.scale
			)
		)
	}
}

private func loadAnchoringDescriptorState(
	url: URL,
	descriptorPath: String
) -> AnchoringDescriptorState {
	let attrs = DeconstructedUSDInterop.getPrimAttributes(
		url: url,
		primPath: descriptorPath
	)?.authoredAttributes ?? []
	let typeLiteral = authoredLiteral(
		in: attrs,
		names: ["type"],
		allowLooseMatch: false
	)
	let target = canonicalAnchoringTarget(parseUSDStringToken(typeLiteral))
	let transformLiteral = authoredLiteral(
		in: attrs,
		names: ["transform"],
		allowLooseMatch: false
	)
	if let parsed = parseAnchoringTransformLiteral(transformLiteral) {
		return AnchoringDescriptorState(
			target: target,
			positionMeters: parsed.positionMeters,
			orientationDegrees: parsed.orientationDegrees,
			scale: parsed.scale,
			hasTransform: true
		)
	}
	return AnchoringDescriptorState(
		target: target,
		positionMeters: SIMD3<Double>(0, 0, 0),
		orientationDegrees: SIMD3<Double>(0, 0, 0),
		scale: SIMD3<Double>(1, 1, 1),
		hasTransform: false
	)
}

private func canonicalAnchoringTarget(_ raw: String) -> String {
	switch raw {
	case "Plane": return "Plane"
	case "Hand": return "Hand"
	case "Head": return "Head"
	case "Object": return "Object"
	default: return "World"
	}
}

private func parseAnchoringTransformLiteral(_ raw: String) -> (
	positionMeters: SIMD3<Double>,
	orientationDegrees: SIMD3<Double>,
	scale: SIMD3<Double>
)? {
	let values = parseNumericValues(raw)
	guard values.count >= 16 else { return nil }

	let row0 = SIMD3<Double>(values[0], values[1], values[2])
	let row1 = SIMD3<Double>(values[4], values[5], values[6])
	let row2 = SIMD3<Double>(values[8], values[9], values[10])
	let sx = max(0.000_001, sqrt(row0.x * row0.x + row0.y * row0.y + row0.z * row0.z))
	let sy = max(0.000_001, sqrt(row1.x * row1.x + row1.y * row1.y + row1.z * row1.z))
	let sz = max(0.000_001, sqrt(row2.x * row2.x + row2.y * row2.y + row2.z * row2.z))
	let scale = SIMD3<Double>(sx, sy, sz)

	let m11 = row0.x / sx
	let m12 = row0.y / sx
	let m13 = row0.z / sx
	let m23 = row1.z / sy
	let m33 = row2.z / sz

	let yRadians = asin(max(-1.0, min(1.0, -m13)))
	let cosY = cos(yRadians)
	let xRadians: Double
	let zRadians: Double
	if Swift.abs(cosY) > 0.000_001 {
		xRadians = atan2(m23, m33)
		zRadians = atan2(m12, m11)
	} else {
		xRadians = atan2(-row2.y / sz, row1.y / sy)
		zRadians = 0
	}

	let orientationDegrees = SIMD3<Double>(
		xRadians * 180.0 / .pi,
		yRadians * 180.0 / .pi,
		zRadians * 180.0 / .pi
	)
	let positionMeters = SIMD3<Double>(values[12], values[13], values[14])
	return (positionMeters, orientationDegrees, scale)
}

private func anchoringMatrixLiteral(
	positionMeters: SIMD3<Double>,
	orientationDegrees: SIMD3<Double>,
	scale: SIMD3<Double>
) -> String {
	let x = orientationDegrees.x * .pi / 180.0
	let y = orientationDegrees.y * .pi / 180.0
	let z = orientationDegrees.z * .pi / 180.0
	let cx = cos(x)
	let sx = sin(x)
	let cy = cos(y)
	let sy = sin(y)
	let cz = cos(z)
	let sz = sin(z)

	let r00 = cy * cz
	let r01 = cy * sz
	let r02 = -sy
	let r10 = sx * sy * cz - cx * sz
	let r11 = sx * sy * sz + cx * cz
	let r12 = sx * cy
	let r20 = cx * sy * cz + sx * sz
	let r21 = cx * sy * sz - sx * cz
	let r22 = cx * cy

	let m00 = r00 * scale.x
	let m01 = r01 * scale.x
	let m02 = r02 * scale.x
	let m10 = r10 * scale.y
	let m11 = r11 * scale.y
	let m12 = r12 * scale.y
	let m20 = r20 * scale.z
	let m21 = r21 * scale.z
	let m22 = r22 * scale.z

	return "( (\(formatUSDFloat(m00)), \(formatUSDFloat(m01)), \(formatUSDFloat(m02)), 0), " +
		"(\(formatUSDFloat(m10)), \(formatUSDFloat(m11)), \(formatUSDFloat(m12)), 0), " +
		"(\(formatUSDFloat(m20)), \(formatUSDFloat(m21)), \(formatUSDFloat(m22)), 0), " +
		"(\(formatUSDFloat(positionMeters.x)), \(formatUSDFloat(positionMeters.y)), \(formatUSDFloat(positionMeters.z)), 1) )"
}

private func parseNumericValues(_ raw: String) -> [Double] {
	let pattern = #"[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?"#
	guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
	let range = NSRange(raw.startIndex..<raw.endIndex, in: raw)
	return regex.matches(in: raw, options: [], range: range).compactMap { match in
		guard let swiftRange = Range(match.range, in: raw) else { return nil }
		return Double(raw[swiftRange])
	}
}

private func parseVector3Components(_ raw: String) -> SIMD3<Double>? {
	let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
	let body: String
	if trimmed.hasPrefix("("), trimmed.hasSuffix(")"), trimmed.count >= 2 {
		body = String(trimmed.dropFirst().dropLast())
	} else {
		body = trimmed
	}
	let values = body
		.split(separator: ",", omittingEmptySubsequences: true)
		.compactMap { Double($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
	guard values.count >= 3 else { return nil }
	return SIMD3<Double>(values[0], values[1], values[2])
}

private func parseDirectionVector3(_ raw: String) -> SIMD3<Double>? {
	guard let vector = parseVector3Components(raw) else { return nil }
	let length = simd_length(vector)
	guard length > 0.000_001 else { return nil }
	return vector / length
}

private func formatUSDFloat3Literal(_ value: SIMD3<Double>) -> String {
	"(\(formatUSDFloat(value.x)), \(formatUSDFloat(value.y)), \(formatUSDFloat(value.z)))"
}

private func rotationDegreesAligningYAxis(to targetUp: SIMD3<Double>) -> SIMD3<Double> {
	let from = SIMD3<Double>(0, 1, 0)
	let to = simd_normalize(targetUp)
	let dotValue = simd_dot(from, to)
	let clamped = max(-1.0, min(1.0, dotValue))
	let quaternion: simd_quatd
	if clamped > 0.999_999 {
		quaternion = simd_quatd(angle: 0, axis: SIMD3<Double>(1, 0, 0))
	} else if clamped < -0.999_999 {
		quaternion = simd_quatd(angle: .pi, axis: SIMD3<Double>(1, 0, 0))
	} else {
		let axis = simd_normalize(simd_cross(from, to))
		let angle = acos(clamped)
		quaternion = simd_quatd(angle: angle, axis: axis)
	}
	return eulerDegreesXYZ(from: quaternion)
}

private func eulerDegreesXYZ(from quaternion: simd_quatd) -> SIMD3<Double> {
	let w = quaternion.real
	let x = quaternion.imag.x
	let y = quaternion.imag.y
	let z = quaternion.imag.z

	let sinrCosp = 2 * (w * x + y * z)
	let cosrCosp = 1 - 2 * (x * x + y * y)
	let roll = atan2(sinrCosp, cosrCosp)

	let sinp = 2 * (w * y - z * x)
	let pitch: Double
	if Swift.abs(sinp) >= 1 {
		pitch = copysign(Double.pi / 2, sinp)
	} else {
		pitch = asin(sinp)
	}

	let sinyCosp = 2 * (w * z + x * y)
	let cosyCosp = 1 - 2 * (y * y + z * z)
	let yaw = atan2(sinyCosp, cosyCosp)

	let radians = SIMD3<Double>(roll, pitch, yaw)
	return radians * (180.0 / .pi)
}

private func normalizedMeshSortingGroupPath(_ raw: String) -> String? {
	let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
	if trimmed.isEmpty || trimmed == "None" {
		return nil
	}
	if trimmed.hasPrefix("/") {
		return trimmed
	}
	return "/Root/\(trimmed)"
}

private func parentPrimPath(of path: String) -> String? {
	let components = path.split(separator: "/")
	guard components.count > 1 else { return nil }
	return "/" + components.dropLast().joined(separator: "/")
}

private func primName(of path: String) -> String? {
	let components = path.split(separator: "/")
	guard let last = components.last, !last.isEmpty else { return nil }
	return String(last)
}

private func resolvedMaterialBindingPrimPath(
	from selectedPrimPath: String,
	nodes: [SceneNode]
) -> String {
	guard let selectedNode = findNode(id: selectedPrimPath, in: nodes) else {
		return selectedPrimPath
	}
	let selectedType = selectedNode.typeName?.lowercased() ?? ""
	guard selectedType.contains("material") || selectedType.contains("shader")
	else {
		return selectedPrimPath
	}
	var path = selectedPrimPath
	while true {
		let components = path.split(separator: "/")
		guard components.count > 1 else { return selectedPrimPath }
		path = "/" + components.dropLast().joined(separator: "/")
		guard let ancestor = findNode(id: path, in: nodes) else {
			continue
		}
		let type = ancestor.typeName?.lowercased() ?? ""
		if !(type.contains("material") || type.contains("shader")) {
			return ancestor.path
		}
	}
}

private func completePrimLoad(
	state: inout InspectorFeature.State,
	section: PrimLoadSection
) {
	state.pendingPrimLoads.remove(section)
	state.primIsLoading = !state.pendingPrimLoads.isEmpty
}

private struct ComponentParameterAuthoringSpec {
	enum Operation {
		case set(valueLiteral: String)
		case clear
	}

	let attributeType: String
	let attributeName: String
	let operation: Operation
	let primPathSuffix: String?
}

private func componentParameterAuthoringSpec(
	componentIdentifier: String,
	parameterKey: String,
	value: InspectorComponentParameterValue
) -> ComponentParameterAuthoringSpec? {
	switch (componentIdentifier, parameterKey, value) {
		case (
			"RealityKit.Accessibility", "isAccessibilityElement", .bool(let boolValue)
		):
		return ComponentParameterAuthoringSpec(
			attributeType: "bool",
			attributeName: "isEnabled",
				operation: .set(valueLiteral: usdBoolLiteral(boolValue)),
				primPathSuffix: nil
			)
		case ("RealityKit.InputTarget", "enabled", .bool(let boolValue)):
			return ComponentParameterAuthoringSpec(
				attributeType: "bool",
				attributeName: "enabled",
				operation: .set(valueLiteral: usdBoolLiteral(boolValue)),
				primPathSuffix: nil
			)
		case ("RealityKit.InputTarget", "allowedInput", .string(let value)):
			switch value {
			case "Direct":
				return ComponentParameterAuthoringSpec(
					attributeType: "bool",
					attributeName: "allowsDirectInput",
					operation: .set(valueLiteral: "1"),
					primPathSuffix: nil
				)
			case "Indirect":
				return ComponentParameterAuthoringSpec(
					attributeType: "bool",
					attributeName: "allowsDirectInput",
					operation: .set(valueLiteral: "0"),
					primPathSuffix: nil
				)
			default:
				return ComponentParameterAuthoringSpec(
					attributeType: "bool",
					attributeName: "allowsDirectInput",
					operation: .clear,
					primPathSuffix: nil
				)
			}
		case ("RealityKit.Accessibility", "label", .string(let stringValue)):
			return ComponentParameterAuthoringSpec(
			attributeType: "string",
			attributeName: "label",
			operation: .set(valueLiteral: quoteUSDString(stringValue)),
			primPathSuffix: nil
		)
	case ("RealityKit.Accessibility", "value", .string(let stringValue)):
		return ComponentParameterAuthoringSpec(
			attributeType: "string",
			attributeName: "value",
			operation: .set(valueLiteral: quoteUSDString(stringValue)),
			primPathSuffix: nil
		)
	case ("RealityKit.Billboard", "blendFactor", .double(let numberValue)):
		return ComponentParameterAuthoringSpec(
			attributeType: "float",
			attributeName: "blendFactor",
			operation: .set(valueLiteral: formatUSDFloat(numberValue)),
			primPathSuffix: nil
		)
	case ("RealityKit.Reverb", "preset", .string(let displayPreset)):
		let token = mapReverbPresetToToken(displayPreset)
		return ComponentParameterAuthoringSpec(
			attributeType: "token",
			attributeName: "reverbPreset",
			operation: .set(valueLiteral: quoteUSDString(token)),
			primPathSuffix: nil
		)
	case ("RealityKit.AmbientAudio", "gain", .double(let value)):
		return ComponentParameterAuthoringSpec(
			attributeType: "float",
			attributeName: "gain",
			operation: .set(valueLiteral: formatUSDFloat(value)),
			primPathSuffix: nil
		)
	case ("RealityKit.SpatialAudio", "gain", .double(let value)):
		return ComponentParameterAuthoringSpec(
			attributeType: "float",
			attributeName: "gain",
			operation: .set(valueLiteral: formatUSDFloat(value)),
			primPathSuffix: nil
		)
	case ("RealityKit.SpatialAudio", "directLevel", .double(let value)):
		return ComponentParameterAuthoringSpec(
			attributeType: "float",
			attributeName: "directLevel",
			operation: .set(valueLiteral: formatUSDFloat(value)),
			primPathSuffix: nil
		)
	case ("RealityKit.SpatialAudio", "reverbLevel", .double(let value)):
		return ComponentParameterAuthoringSpec(
			attributeType: "float",
			attributeName: "reverbLevel",
			operation: .set(valueLiteral: formatUSDFloat(value)),
			primPathSuffix: nil
		)
	case ("RealityKit.SpatialAudio", "rolloffFactor", .double(let value)):
		return ComponentParameterAuthoringSpec(
			attributeType: "float",
			attributeName: "rolloffFactor",
			operation: .set(valueLiteral: formatUSDFloat(value)),
			primPathSuffix: nil
		)
	case ("RealityKit.SpatialAudio", "directivityFocus", .double(let value)):
		return ComponentParameterAuthoringSpec(
			attributeType: "float",
			attributeName: "directivityFocus",
			operation: .set(valueLiteral: formatUSDFloat(value)),
			primPathSuffix: nil
		)
	case ("RealityKit.ChannelAudio", "gain", .double(let value)):
		return ComponentParameterAuthoringSpec(
			attributeType: "float",
			attributeName: "gain",
			operation: .set(valueLiteral: formatUSDFloat(value)),
			primPathSuffix: nil
		)
	case ("RealityKit.HierarchicalFade", "opacity", .double(let value)):
		return ComponentParameterAuthoringSpec(
			attributeType: "float",
			attributeName: "opacity",
			operation: .set(valueLiteral: formatUSDFloat(value)),
			primPathSuffix: nil
		)
	case ("RealityKit.ImageBasedLight", "isGlobalIBL", .bool(let boolValue)):
		return ComponentParameterAuthoringSpec(
			attributeType: "bool",
			attributeName: "isGlobalIBL",
			operation: .set(valueLiteral: usdBoolLiteral(boolValue)),
			primPathSuffix: nil
		)
	case ("RealityKit.VirtualEnvironmentProbe", "blendMode", .string(let value)):
		return ComponentParameterAuthoringSpec(
			attributeType: "token",
			attributeName: "blendMode",
			operation: .set(valueLiteral: quoteUSDString(value)),
			primPathSuffix: nil
		)
	case ("RealityKit.CustomDockingRegion", "width", .double(let valueCM)):
		return ComponentParameterAuthoringSpec(
			attributeType: "float3",
			attributeName: "max",
			operation: .set(valueLiteral: dockingRegionMaxLiteral(widthCM: valueCM)),
			primPathSuffix: "m_bounds"
		)
	case ("RealityKit.Collider", "mode", .string(let value)):
		return ComponentParameterAuthoringSpec(
			attributeType: "token",
			attributeName: "type",
			operation: .set(valueLiteral: quoteUSDString(value)),
			primPathSuffix: nil
		)
	case ("RealityKit.Collider", "shape", .string(let value)):
		return ComponentParameterAuthoringSpec(
			attributeType: "token",
			attributeName: "shapeType",
			operation: .set(valueLiteral: quoteUSDString(value)),
			primPathSuffix: "Shape"
		)
	case ("RealityKit.Collider", "extent", .string(let value)):
		return ComponentParameterAuthoringSpec(
			attributeType: "float3",
			attributeName: "extent",
			operation: .set(valueLiteral: formatCollisionExtent(value)),
			primPathSuffix: "Shape"
		)
	case ("RealityKit.Collider", "radius", .double(let valueCM)):
		return ComponentParameterAuthoringSpec(
			attributeType: "float",
			attributeName: "radius",
			operation: .set(valueLiteral: formatUSDFloat(max(0, valueCM) / 100.0)),
			primPathSuffix: "Shape"
		)
	case ("RealityKit.Collider", "height", .double(let valueCM)):
		return ComponentParameterAuthoringSpec(
			attributeType: "float",
			attributeName: "height",
			operation: .set(valueLiteral: formatUSDFloat(max(0, valueCM) / 100.0)),
			primPathSuffix: "Shape"
		)
	case ("RealityKit.Collider", "group", .string(let value)):
		return ComponentParameterAuthoringSpec(
			attributeType: "uint",
			attributeName: "group",
			operation: .set(valueLiteral: value == "All" ? "4294967295" : "1"),
			primPathSuffix: nil
		)
	case ("RealityKit.Collider", "mask", .string(let value)):
		return ComponentParameterAuthoringSpec(
			attributeType: "uint",
			attributeName: "mask",
			operation: .set(valueLiteral: value == "All" ? "4294967295" : "1"),
			primPathSuffix: nil
		)
	case ("RealityKit.Collider", "group", .double(let numberValue)):
		return ComponentParameterAuthoringSpec(
			attributeType: "uint",
			attributeName: "group",
			operation: .set(valueLiteral: formatUSDUInt(numberValue)),
			primPathSuffix: nil
		)
	case ("RealityKit.Collider", "mask", .double(let numberValue)):
		return ComponentParameterAuthoringSpec(
			attributeType: "uint",
			attributeName: "mask",
			operation: .set(valueLiteral: formatUSDUInt(numberValue)),
			primPathSuffix: nil
		)
	case ("RealityKit.Collider", "type", .string(let value)):
		return ComponentParameterAuthoringSpec(
			attributeType: "token",
			attributeName: "type",
			operation: .set(valueLiteral: quoteUSDString(value)),
			primPathSuffix: nil
		)
	case ("RealityKit.RigidBody", "motionType", .string(let value)):
		return ComponentParameterAuthoringSpec(
			attributeType: "token",
			attributeName: "motionType",
			operation: .set(valueLiteral: quoteUSDString(value)),
			primPathSuffix: nil
		)
	case ("RealityKit.RigidBody", "isCCDEnabled", .bool(let boolValue)):
		return ComponentParameterAuthoringSpec(
			attributeType: "bool",
			attributeName: "isCCDEnabled",
			operation: .set(valueLiteral: usdBoolLiteral(boolValue)),
			primPathSuffix: nil
		)
	case ("RealityKit.RigidBody", "gravityEnabled", .bool(let boolValue)):
		return ComponentParameterAuthoringSpec(
			attributeType: "bool",
			attributeName: "gravityEnabled",
			operation: .set(valueLiteral: usdBoolLiteral(boolValue)),
			primPathSuffix: nil
		)
	case ("RealityKit.RigidBody", "angularDamping", .double(let value)):
		return ComponentParameterAuthoringSpec(
			attributeType: "float",
			attributeName: "angularDamping",
			operation: .set(valueLiteral: formatUSDFloat(value)),
			primPathSuffix: nil
		)
	case ("RealityKit.RigidBody", "linearDamping", .double(let value)):
		return ComponentParameterAuthoringSpec(
			attributeType: "float",
			attributeName: "linearDamping",
			operation: .set(valueLiteral: formatUSDFloat(value)),
			primPathSuffix: nil
		)
	case ("RealityKit.RigidBody", "staticFriction", .double(let value)):
		return ComponentParameterAuthoringSpec(
			attributeType: "double",
			attributeName: "staticFriction",
			operation: .set(valueLiteral: formatUSDFloat(value)),
			primPathSuffix: "material"
		)
	case ("RealityKit.RigidBody", "dynamicFriction", .double(let value)):
		return ComponentParameterAuthoringSpec(
			attributeType: "double",
			attributeName: "dynamicFriction",
			operation: .set(valueLiteral: formatUSDFloat(value)),
			primPathSuffix: "material"
		)
	case ("RealityKit.RigidBody", "restitution", .double(let value)):
		return ComponentParameterAuthoringSpec(
			attributeType: "double",
			attributeName: "restitution",
			operation: .set(valueLiteral: formatUSDFloat(value)),
			primPathSuffix: "material"
		)
	case ("RealityKit.RigidBody", "m_mass", .double(let value)):
		return ComponentParameterAuthoringSpec(
			attributeType: "float",
			attributeName: "m_mass",
			operation: .set(valueLiteral: formatUSDFloat(value)),
			primPathSuffix: "massFrame"
		)
	case ("RealityKit.RigidBody", "m_inertia", .string(let value)):
		return ComponentParameterAuthoringSpec(
			attributeType: "float3",
			attributeName: "m_inertia",
			operation: .set(valueLiteral: formatUSDFloat3(value, fallback: "(0, 0, 0)")),
			primPathSuffix: "massFrame"
		)
	case ("RealityKit.RigidBody", "position", .string(let value)):
		return ComponentParameterAuthoringSpec(
			attributeType: "float3",
			attributeName: "position",
			operation: .set(valueLiteral: formatUSDFloat3(value, fallback: "(0, 0, 0)")),
			primPathSuffix: "massFrame/m_pose"
		)
	case ("RealityKit.RigidBody", "orientation", .string(let value)):
		return ComponentParameterAuthoringSpec(
			attributeType: "quatf",
			attributeName: "orientation",
			operation: .set(valueLiteral: formatUSDFloat4(value, fallback: "(1, 0, 0, 0)")),
			primPathSuffix: "massFrame/m_pose"
		)
	case ("RealityKit.RigidBody", "lockTranslationX", .bool(let boolValue)):
		return ComponentParameterAuthoringSpec(
			attributeType: "bool",
			attributeName: "lockTranslationX",
			operation: .set(valueLiteral: usdBoolLiteral(boolValue)),
			primPathSuffix: nil
		)
	case ("RealityKit.RigidBody", "lockTranslationY", .bool(let boolValue)):
		return ComponentParameterAuthoringSpec(
			attributeType: "bool",
			attributeName: "lockTranslationY",
			operation: .set(valueLiteral: usdBoolLiteral(boolValue)),
			primPathSuffix: nil
		)
	case ("RealityKit.RigidBody", "lockTranslationZ", .bool(let boolValue)):
		return ComponentParameterAuthoringSpec(
			attributeType: "bool",
			attributeName: "lockTranslationZ",
			operation: .set(valueLiteral: usdBoolLiteral(boolValue)),
			primPathSuffix: nil
		)
	case ("RealityKit.RigidBody", "lockRotationX", .bool(let boolValue)):
		return ComponentParameterAuthoringSpec(
			attributeType: "bool",
			attributeName: "lockRotationX",
			operation: .set(valueLiteral: usdBoolLiteral(boolValue)),
			primPathSuffix: nil
		)
	case ("RealityKit.RigidBody", "lockRotationY", .bool(let boolValue)):
		return ComponentParameterAuthoringSpec(
			attributeType: "bool",
			attributeName: "lockRotationY",
			operation: .set(valueLiteral: usdBoolLiteral(boolValue)),
			primPathSuffix: nil
		)
	case ("RealityKit.RigidBody", "lockRotationZ", .bool(let boolValue)):
		return ComponentParameterAuthoringSpec(
			attributeType: "bool",
			attributeName: "lockRotationZ",
			operation: .set(valueLiteral: usdBoolLiteral(boolValue)),
			primPathSuffix: nil
		)
		case ("RealityKit.MotionState", "linearVelocity", .string(let value)):
			return ComponentParameterAuthoringSpec(
				attributeType: "float3",
				attributeName: "m_userSetLinearVelocity",
				operation: .set(valueLiteral: formatUSDFloat3(value, fallback: "(0, 0, 0)")),
				primPathSuffix: nil
			)
		case ("RealityKit.MotionState", "angularVelocity", .string(let value)):
			return ComponentParameterAuthoringSpec(
				attributeType: "float3",
				attributeName: "m_userSetAngularVelocity",
				operation: .set(valueLiteral: formatUSDFloat3(value, fallback: "(0, 0, 0)")),
				primPathSuffix: nil
			)
		case ("RealityKit.PointLight", "color", .string(let value)):
			return ComponentParameterAuthoringSpec(
				attributeType: "float3",
				attributeName: "color",
				operation: .set(valueLiteral: formatUSDColor3(value)),
			primPathSuffix: nil
		)
	case ("RealityKit.PointLight", "intensity", .double(let value)):
		return ComponentParameterAuthoringSpec(
			attributeType: "float",
			attributeName: "intensity",
			operation: .set(valueLiteral: formatUSDFloat(value)),
			primPathSuffix: nil
		)
	case ("RealityKit.PointLight", "attenuationRadius", .double(let value)):
		return ComponentParameterAuthoringSpec(
			attributeType: "float",
			attributeName: "attenuationRadius",
			operation: .set(valueLiteral: formatUSDFloat(value)),
			primPathSuffix: nil
		)
	case ("RealityKit.PointLight", "attenuationFalloff", .double(let value)):
		return ComponentParameterAuthoringSpec(
			attributeType: "float",
			attributeName: "attenuationFalloffExponent",
			operation: .set(valueLiteral: formatUSDFloat(value)),
			primPathSuffix: nil
		)
	case ("RealityKit.SpotLight", "color", .string(let value)):
		return ComponentParameterAuthoringSpec(
			attributeType: "float3",
			attributeName: "color",
			operation: .set(valueLiteral: formatUSDColor3(value)),
			primPathSuffix: nil
		)
	case ("RealityKit.SpotLight", "intensity", .double(let value)):
		return ComponentParameterAuthoringSpec(
			attributeType: "float",
			attributeName: "intensity",
			operation: .set(valueLiteral: formatUSDFloat(value)),
			primPathSuffix: nil
		)
	case ("RealityKit.SpotLight", "innerAngle", .double(let value)):
		return ComponentParameterAuthoringSpec(
			attributeType: "float",
			attributeName: "innerAngle",
			operation: .set(valueLiteral: formatUSDFloat(value)),
			primPathSuffix: nil
		)
	case ("RealityKit.SpotLight", "outerAngle", .double(let value)):
		return ComponentParameterAuthoringSpec(
			attributeType: "float",
			attributeName: "outerAngle",
			operation: .set(valueLiteral: formatUSDFloat(value)),
			primPathSuffix: nil
		)
	case ("RealityKit.SpotLight", "attenuationRadius", .double(let value)):
		return ComponentParameterAuthoringSpec(
			attributeType: "float",
			attributeName: "attenuationRadius",
			operation: .set(valueLiteral: formatUSDFloat(value)),
			primPathSuffix: nil
		)
	case ("RealityKit.SpotLight", "attenuationFalloff", .double(let value)):
		return ComponentParameterAuthoringSpec(
			attributeType: "float",
			attributeName: "attenuationFalloffExponent",
			operation: .set(valueLiteral: formatUSDFloat(value)),
			primPathSuffix: nil
		)
	case ("RealityKit.SpotLight", "shadowEnabled", .bool(let value)):
		return ComponentParameterAuthoringSpec(
			attributeType: "bool",
			attributeName: "isEnabled",
			operation: .set(valueLiteral: usdBoolLiteral(value)),
			primPathSuffix: "Shadow"
		)
	case ("RealityKit.SpotLight", "shadowBias", .double(let value)):
		return ComponentParameterAuthoringSpec(
			attributeType: "float",
			attributeName: "depthBias",
			operation: .set(valueLiteral: formatUSDFloat(value)),
			primPathSuffix: "Shadow"
		)
	case ("RealityKit.SpotLight", "shadowCullMode", .string(let value)):
		if value == "Default" || value == "None" {
			return ComponentParameterAuthoringSpec(
				attributeType: "token",
				attributeName: "cullMode",
				operation: .clear,
				primPathSuffix: "Shadow"
			)
		}
		return ComponentParameterAuthoringSpec(
			attributeType: "token",
			attributeName: "cullMode",
			operation: .set(valueLiteral: quoteUSDString(value)),
			primPathSuffix: "Shadow"
		)
	case ("RealityKit.SpotLight", "shadowNear", .string(let value)):
		if value == "Automatic" {
			return ComponentParameterAuthoringSpec(
				attributeType: "token",
				attributeName: "zNear",
				operation: .clear,
				primPathSuffix: "Shadow"
			)
		}
		return ComponentParameterAuthoringSpec(
			attributeType: "token",
			attributeName: "zNear",
			operation: .set(valueLiteral: quoteUSDString(value)),
			primPathSuffix: "Shadow"
		)
	case ("RealityKit.SpotLight", "shadowFar", .string(let value)):
		if value == "Automatic" {
			return ComponentParameterAuthoringSpec(
				attributeType: "token",
				attributeName: "zFar",
				operation: .clear,
				primPathSuffix: "Shadow"
			)
		}
		return ComponentParameterAuthoringSpec(
			attributeType: "token",
			attributeName: "zFar",
			operation: .set(valueLiteral: quoteUSDString(value)),
			primPathSuffix: "Shadow"
		)
	case ("RealityKit.DirectionalLight", "color", .string(let value)):
		return ComponentParameterAuthoringSpec(
			attributeType: "float3",
			attributeName: "color",
			operation: .set(valueLiteral: formatUSDColor3(value)),
			primPathSuffix: nil
		)
	case ("RealityKit.DirectionalLight", "intensity", .double(let value)):
		return ComponentParameterAuthoringSpec(
			attributeType: "float",
			attributeName: "intensity",
			operation: .set(valueLiteral: formatUSDFloat(value)),
			primPathSuffix: nil
		)
	case ("RealityKit.DirectionalLight", "shadowEnabled", .bool(let value)):
		return ComponentParameterAuthoringSpec(
			attributeType: "bool",
			attributeName: "isEnabled",
			operation: .set(valueLiteral: usdBoolLiteral(value)),
			primPathSuffix: "Shadow"
		)
	case ("RealityKit.DirectionalLight", "shadowBias", .double(let value)):
		return ComponentParameterAuthoringSpec(
			attributeType: "float",
			attributeName: "depthBias",
			operation: .set(valueLiteral: formatUSDFloat(value)),
			primPathSuffix: "Shadow"
		)
	case ("RealityKit.DirectionalLight", "shadowCullMode", .string(let value)):
		if value == "Default" {
			return ComponentParameterAuthoringSpec(
				attributeType: "token",
				attributeName: "cullMode",
				operation: .clear,
				primPathSuffix: "Shadow"
			)
		}
		return ComponentParameterAuthoringSpec(
			attributeType: "token",
			attributeName: "cullMode",
			operation: .set(valueLiteral: quoteUSDString(value)),
			primPathSuffix: "Shadow"
		)
	case (
		"RealityKit.DirectionalLight", "shadowProjectionType", .string(let value)
	):
		if value == "Automatic" {
			return ComponentParameterAuthoringSpec(
				attributeType: "token",
				attributeName: "projectionType",
				operation: .clear,
				primPathSuffix: "Shadow"
			)
		}
		return ComponentParameterAuthoringSpec(
			attributeType: "token",
			attributeName: "projectionType",
			operation: .set(valueLiteral: quoteUSDString(value)),
			primPathSuffix: "Shadow"
		)
	case (
		"RealityKit.DirectionalLight", "shadowOrthographicScale", .double(let value)
	):
		return ComponentParameterAuthoringSpec(
			attributeType: "float",
			attributeName: "orthographicScale",
			operation: .set(valueLiteral: formatUSDFloat(value)),
			primPathSuffix: "Shadow"
		)
	case ("RealityKit.DirectionalLight", "shadowZBounds", .string(let value)):
		return ComponentParameterAuthoringSpec(
			attributeType: "float2",
			attributeName: "zBounds",
			operation: .set(valueLiteral: formatUSDFloat2(value)),
			primPathSuffix: "Shadow"
		)
	default:
		return nil
	}
}

private func supplementalComponentAuthoringSpecs(
	componentIdentifier: String,
	parameterKey: String,
	value: InspectorComponentParameterValue
) -> [ComponentParameterAuthoringSpec] {
	switch (componentIdentifier, parameterKey, value) {
	case (
		"RealityKit.DirectionalLight", "shadowProjectionType", .string(let value)
	):
		if value == "Automatic" {
			return [
				ComponentParameterAuthoringSpec(
					attributeType: "float",
					attributeName: "orthographicScale",
					operation: .clear,
					primPathSuffix: "Shadow"
				),
				ComponentParameterAuthoringSpec(
					attributeType: "float2",
					attributeName: "zBounds",
					operation: .clear,
					primPathSuffix: "Shadow"
				),
			]
		}
		return []
	case ("RealityKit.DirectionalLight", "shadowOrthographicScale", .double):
		return [
			ComponentParameterAuthoringSpec(
				attributeType: "token",
				attributeName: "projectionType",
				operation: .set(valueLiteral: quoteUSDString("Fixed")),
				primPathSuffix: "Shadow"
			)
		]
	case ("RealityKit.DirectionalLight", "shadowZBounds", .string):
		return [
			ComponentParameterAuthoringSpec(
				attributeType: "token",
				attributeName: "projectionType",
				operation: .set(valueLiteral: quoteUSDString("Fixed")),
				primPathSuffix: "Shadow"
			)
		]
	case ("RealityKit.InputTarget", "allowedInput", .string(let value)):
		switch value {
		case "Direct":
			return [
				ComponentParameterAuthoringSpec(
					attributeType: "bool",
					attributeName: "allowsIndirectInput",
					operation: .set(valueLiteral: "0"),
					primPathSuffix: nil
				)
			]
		case "Indirect":
			return [
				ComponentParameterAuthoringSpec(
					attributeType: "bool",
					attributeName: "allowsIndirectInput",
					operation: .set(valueLiteral: "1"),
					primPathSuffix: nil
				)
			]
		default:
			return [
				ComponentParameterAuthoringSpec(
					attributeType: "bool",
					attributeName: "allowsIndirectInput",
					operation: .clear,
					primPathSuffix: nil
				)
			]
			}
	case ("RealityKit.CustomDockingRegion", "width", .double(let valueCM)):
		return [
			ComponentParameterAuthoringSpec(
				attributeType: "float3",
				attributeName: "min",
				operation: .set(valueLiteral: dockingRegionMinLiteral(widthCM: valueCM)),
				primPathSuffix: "m_bounds"
			)
		]
	default:
		return []
	}
}

private func quoteUSDString(_ text: String) -> String {
	let escaped =
		text
		.replacingOccurrences(of: "\\", with: "\\\\")
		.replacingOccurrences(of: "\"", with: "\\\"")
	return "\"\(escaped)\""
}

private func usdBoolLiteral(_ value: Bool) -> String {
	value ? "1" : "0"
}

private func formatUSDFloat(_ value: Double) -> String {
	let formatted = String(format: "%.6f", value)
	return formatted.replacingOccurrences(
		of: #"(\.\d*?[1-9])0+$|\.0+$"#,
		with: "$1",
		options: .regularExpression
	)
}

private func formatUSDUInt(_ value: Double) -> String {
	let rounded = max(0, value.rounded())
	return String(UInt64(rounded))
}

private func formatUSDColor3(_ raw: String) -> String {
	formatUSDFloat3(raw, fallback: "(1, 1, 1)")
}

private func formatUSDFloat3(_ raw: String, fallback: String) -> String {
	let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
	if trimmed.hasPrefix("("), trimmed.hasSuffix(")") {
		return trimmed
	}
	let parts =
		trimmed
		.split(separator: ",")
		.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
	if parts.count == 3 {
		return "(\(parts[0]), \(parts[1]), \(parts[2]))"
	}
	return fallback
}

private func formatUSDFloat4(_ raw: String, fallback: String) -> String {
	let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
	if trimmed.hasPrefix("("), trimmed.hasSuffix(")") {
		return trimmed
	}
	let parts =
		trimmed
		.split(separator: ",")
		.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
	if parts.count == 4 {
		return "(\(parts[0]), \(parts[1]), \(parts[2]), \(parts[3]))"
	}
	return fallback
}

private func formatUSDFloat2(_ raw: String) -> String {
	let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
	if trimmed.hasPrefix("("), trimmed.hasSuffix(")") {
		return trimmed
	}
	let parts =
		trimmed
		.split(separator: ",")
		.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
	if parts.count == 2 {
		return "(\(parts[0]), \(parts[1]))"
	}
	return "(0.02, 20)"
}

private func formatCollisionExtent(_ raw: String) -> String {
	guard let cm = parseVector3Components(raw) else {
		return "(0.2, 0.2, 0.2)"
	}
	let meters = cm / 100.0
	return "(\(formatUSDFloat(meters.x)), \(formatUSDFloat(meters.y)), \(formatUSDFloat(meters.z)))"
}

private func dockingRegionMaxLiteral(widthCM: Double) -> String {
	let clamped = max(0, widthCM)
	let halfWidthMeters = clamped / 200.0
	let halfHeightMeters = halfWidthMeters / 2.4
	return "(\(formatUSDFloat(halfWidthMeters)), \(formatUSDFloat(halfHeightMeters)), 0)"
}

private func dockingRegionMinLiteral(widthCM: Double) -> String {
	let clamped = max(0, widthCM)
	let halfWidthMeters = clamped / 200.0
	let halfHeightMeters = halfWidthMeters / 2.4
	return "(\(formatUSDFloat(-halfWidthMeters)), \(formatUSDFloat(-halfHeightMeters)), 0)"
}

private func mapReverbPresetToToken(_ displayName: String) -> String {
	switch displayName {
	case "Small Room": return "SmallRoom"
	case "Large Room": return "LargeRoom"
	case "Cathedral": return "Cathedral"
	case "Plate": return "Plate"
	default: return "MediumRoomTreated"
	}
}

private enum PrimAttributesLoadCancellationID {
	case load
}

private enum PrimTransformSaveCancellationID {
	case save
}

private enum PrimVariantSelectionCancellationID {
	case apply
}

private struct ComponentParameterMutationCancellationID: Hashable {
	let componentPath: String
}

public enum PrimLoadSection: Hashable {
	case attributes
	case transform
	case variants
	case references
	case materialBinding
	case materials
}

private enum PlaybackTimerID {
	case playback
}

private func startPlaybackTimer(
	state: InspectorFeature.State,
	clock: any Clock<Duration>
) -> Effect<InspectorFeature.Action> {
	let fps = max(state.playbackData?.timeCodesPerSecond ?? 24.0, 1.0)
	let interval = Duration.seconds(1.0 / fps)
	return .run { send in
		while true {
			try await clock.sleep(for: interval)
			await send(.playbackTick)
		}
	}
	.cancellable(id: PlaybackTimerID.playback, cancelInFlight: true)
}

private func shouldLoop(_ playbackMode: String?) -> Bool {
	let mode = playbackMode?.lowercased() ?? ""
	return mode.contains("loop") || mode.contains("repeat")
}
