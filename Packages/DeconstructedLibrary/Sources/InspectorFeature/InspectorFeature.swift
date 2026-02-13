import ComposableArchitecture
import DeconstructedUSDInterop
import Foundation
import InspectorModels
import SceneGraphModels
import USDInterfaces

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
			public var boundMaterial: USDMaterialInfo?
			public var availableMaterials: [USDMaterialInfo]
			public var sceneNodes: [SceneNode]
			public var isLoading: Bool
			public var errorMessage: String?
			public var primIsLoading: Bool
			public var primErrorMessage: String?
			public var pendingPrimLoads: Set<PrimLoadSection>
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
				boundMaterial: USDMaterialInfo? = nil,
				availableMaterials: [USDMaterialInfo] = [],
				sceneNodes: [SceneNode] = [],
				isLoading: Bool = false,
				errorMessage: String? = nil,
				primIsLoading: Bool = false,
				primErrorMessage: String? = nil,
				pendingPrimLoads: Set<PrimLoadSection> = [],
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
				self.boundMaterial = boundMaterial
				self.availableMaterials = availableMaterials
				self.sceneNodes = sceneNodes
				self.isLoading = isLoading
				self.errorMessage = errorMessage
				self.primIsLoading = primIsLoading
				self.primErrorMessage = primErrorMessage
				self.pendingPrimLoads = pendingPrimLoads
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

				case let .sceneURLChanged(url):
				print("[InspectorFeature] sceneURLChanged: \(url?.lastPathComponent ?? "nil")")
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
					state.boundMaterial = nil
					state.availableMaterials = []
					state.primIsLoading = false
					state.primErrorMessage = nil
					state.pendingPrimLoads = []
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

				case let .selectionChanged(nodeID):
					state.selectedNodeID = nodeID
					state.primVariantScopePath = nil
					state.primAttributes = nil
					state.primTransform = nil
					state.primVariantSets = []
					state.primReferences = []
					state.primMaterialBinding = nil
					state.primMaterialBindingStrength = nil
					state.boundMaterial = nil
					state.primErrorMessage = nil
					state.pendingPrimLoads = []
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
					state.primVariantScopePath = variantScopePath
					state.pendingPrimLoads = [
						.attributes,
						.transform,
						.variants,
						.references,
						.materialBinding,
						.materials
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
							await send(.primTransformLoadFailed("No transform data available."))
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

						let binding = DeconstructedUSDInterop.materialBinding(url: url, primPath: materialBindingPrimPath)
						let strength = DeconstructedUSDInterop.materialBindingStrength(url: url, primPath: materialBindingPrimPath)
						await send(.primMaterialBindingLoaded(binding, strength))
					}
					.cancellable(
						id: PrimAttributesLoadCancellationID.load,
						cancelInFlight: true
					)
				)

			case let .sceneGraphUpdated(nodes):
				print("[InspectorFeature] sceneGraphUpdated: \(nodes.count) root nodes")
				state.sceneNodes = nodes
				let availablePrims = extractAvailablePrims(from: nodes)
				print("[InspectorFeature] Extracted \(availablePrims.count) available prims")
				if var layerData = state.layerData {
					// Layer data already loaded, update it with prims
					layerData.availablePrims = availablePrims
					state.layerData = layerData
					print("[InspectorFeature] Updated layerData with availablePrims")
				}
				return .none

			case let .sceneMetadataLoaded(layerData, playbackData):
				print("[InspectorFeature] layerDataLoaded: defaultPrim=\(layerData.defaultPrim ?? "nil"), mpu=\(layerData.metersPerUnit), upAxis=\(layerData.upAxis)")
				var updatedLayerData = layerData
				// If we have scene nodes, use them to populate availablePrims
				if !state.sceneNodes.isEmpty {
					updatedLayerData.availablePrims = extractAvailablePrims(from: state.sceneNodes)
					print("[InspectorFeature] Applied \(updatedLayerData.availablePrims.count) prims from scene nodes")
				}
				state.layerData = updatedLayerData
				state.playbackData = playbackData
				state.isLoading = false
				state.errorMessage = nil
				state.playbackCurrentTime = playbackData.startTimeCode
				state.playbackIsPlaying = (playbackData.autoPlay ?? false) && playbackData.hasTimeline
				state.playbackIsScrubbing = false
				if state.playbackIsPlaying {
					return startPlaybackTimer(state: state, clock: clock)
				}
				return .none

			case let .sceneMetadataLoadFailed(message):
				state.errorMessage = message
				state.isLoading = false
				return .none

			case let .primAttributesLoaded(attributes):
				state.primAttributes = attributes
				state.primErrorMessage = nil
				completePrimLoad(state: &state, section: .attributes)
				return .none

			case let .primAttributesLoadFailed(message):
				state.primAttributes = nil
				state.primErrorMessage = message
				completePrimLoad(state: &state, section: .attributes)
				return .none

			case let .primTransformLoaded(transform):
				state.primTransform = transform
				state.primErrorMessage = nil
				completePrimLoad(state: &state, section: .transform)
				return .none

				case let .primTransformLoadFailed(message):
					state.primTransform = nil
					state.primErrorMessage = message
					completePrimLoad(state: &state, section: .transform)
					return .none

				case let .primVariantSetsLoaded(sets):
					state.primVariantSets = sets
					completePrimLoad(state: &state, section: .variants)
					return .none

				case let .primVariantSetsLoadFailed(message):
					state.primVariantSets = []
					state.primErrorMessage = message
					completePrimLoad(state: &state, section: .variants)
					return .none

				case let .setVariantSelection(setName, selectionId):
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
							let normalizedSelection = selectionId?.isEmpty == true ? nil : selectionId
							let appliedSelection = refreshed
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
								await send(.primTransformLoadFailed("No transform data available."))
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

				case let .setVariantSelectionSucceeded(sets):
					state.primVariantSets = sets
					state.primErrorMessage = nil
					return .none

				case let .setVariantSelectionFailed(message):
					state.primErrorMessage = "Failed to set variant: \(message)"
					return .none

				case let .primReferencesLoaded(references):
					state.primReferences = references
					completePrimLoad(state: &state, section: .references)
					return .none

				case let .primReferencesLoadFailed(message):
					state.primReferences = []
					state.primErrorMessage = message
					completePrimLoad(state: &state, section: .references)
					return .none

				case let .addReferenceRequested(reference):
					guard let url = state.sceneURL, let primPath = state.selectedNodeID else {
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

				case let .removeReferenceRequested(reference):
					guard let url = state.sceneURL, let primPath = state.selectedNodeID else {
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

				case let .replaceReferenceRequested(old, new):
					guard let url = state.sceneURL, let primPath = state.selectedNodeID else {
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

				case let .primReferencesEditFailed(message):
					state.primErrorMessage = "Failed to edit references: \(message)"
					return .none

				case let .primMaterialBindingLoaded(binding, strength):
					state.primMaterialBinding = normalizeMaterialPath(binding)
					state.primMaterialBindingStrength = strength
					updateBoundMaterial(state: &state)
					completePrimLoad(state: &state, section: .materialBinding)
					return .none

				case let .availableMaterialsLoaded(materials):
					state.availableMaterials = materials
					updateBoundMaterial(state: &state)
					completePrimLoad(state: &state, section: .materials)
					return .none

				case let .setMaterialBinding(materialPath):
					guard let url = state.sceneURL, let primPath = state.selectedNodeID else {
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
								print("[InspectorFeature] setMaterialBinding requested: selectedPrim=\(primPath), bindingPrim=\(bindingPrimPath), material=\(normalizedMaterialPath)")
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
							let refreshed = DeconstructedUSDInterop.materialBinding(url: url, primPath: bindingPrimPath)
							let refreshedStrength = DeconstructedUSDInterop.materialBindingStrength(url: url, primPath: bindingPrimPath)
							print("[InspectorFeature] Final material binding: \(normalizeMaterialPath(refreshed) ?? "nil"), strength=\(String(describing: refreshedStrength))")
							await send(.primMaterialBindingLoaded(refreshed, refreshedStrength))
							await send(.setMaterialBindingSucceeded)
						} catch {
							await send(.setMaterialBindingFailed(error.localizedDescription))
						}
					}

				case .setMaterialBindingSucceeded:
					return .none

				case let .setMaterialBindingFailed(message):
					state.primErrorMessage = message
					return .none

				case let .setMaterialBindingStrength(strength):
					guard let url = state.sceneURL, let primPath = state.selectedNodeID else {
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
							await send(.setMaterialBindingStrengthFailed(error.localizedDescription))
						}
					}

				case .setMaterialBindingStrengthSucceeded:
					return .none

				case let .setMaterialBindingStrengthFailed(message):
					state.primErrorMessage = message
					return .none

				case let .primTransformChanged(transform):
				guard let url = state.sceneURL,
				      let primPath = state.selectedNodeID else {
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

			case let .primTransformSaveFailed(message):
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

			case let .defaultPrimChanged(primPath):
				guard let url = state.sceneURL else {
					return .none
				}
				if var layerData = state.layerData {
					layerData.defaultPrim = primPath.isEmpty ? nil : primPath
					state.layerData = layerData
				}
				return .run { send in
					do {
						try DeconstructedUSDInterop.setDefaultPrim(url: url, primPath: primPath)
						await send(.layerDataUpdateSucceeded)
					} catch {
						await send(.layerDataUpdateFailed(error.localizedDescription))
					}
				}

			case let .metersPerUnitChanged(value):
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

			case let .upAxisChanged(axis):
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

			case let .layerDataUpdateFailed(message):
				state.errorMessage = message
				return .none

			case .playbackPlayPauseTapped:
				guard let playbackData = state.playbackData,
				      playbackData.hasTimeline else {
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

			case let .playbackScrubbed(value, isEditing):
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
				      state.playbackIsPlaying else {
					return .cancel(id: PlaybackTimerID.playback)
				}
				let fps = playbackData.timeCodesPerSecond > 0
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

private func loadLayerData(url: URL, send: Send<InspectorFeature.Action>) async {
	print("[InspectorFeature] loadLayerData starting for: \(url.lastPathComponent)")
	let metadata = DeconstructedUSDInterop.getStageMetadata(url: url)
	print("[InspectorFeature] Got metadata: defaultPrim=\(metadata.defaultPrimName ?? "nil"), mpu=\(metadata.metersPerUnit?.description ?? "nil"), upAxis=\(metadata.upAxis ?? "nil")")

	let upAxis: UpAxis
	if let axisString = metadata.upAxis,
	   let axis = UpAxis(rawValue: axisString) {
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
		prims.append(contentsOf: collectPrimPaths(from: node.children, parentPath: node.name))
	}
	return prims
}

private func collectPrimPaths(from nodes: [SceneNode], parentPath: String) -> [String] {
	var paths: [String] = []
	for node in nodes {
		let fullPath = "\(parentPath)/\(node.name)"
		paths.append(fullPath)
		paths.append(contentsOf: collectPrimPaths(from: node.children, parentPath: fullPath))
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

private func resolvedVariantScopePrimPath(from selectedPrimPath: String, url: URL) -> String {
	var currentPath = selectedPrimPath
	while true {
		// If the currently selected prim has its own variant sets (e.g. realistic -> lods),
		// keep it as the inspector scope and do not walk up to parent set owners.
		if let currentSets = try? DeconstructedUSDInterop.listPrimVariantSets(
			url: url,
			primPath: currentPath
		),
		   !currentSets.isEmpty {
			return currentPath
		}

		guard let parentPath = parentPrimPath(of: currentPath) else {
			return currentPath
		}
		let childName = String(currentPath.split(separator: "/").last ?? "")
		guard !childName.isEmpty else {
			return currentPath
		}
		guard let parentSets = try? DeconstructedUSDInterop.listPrimVariantSets(
			url: url,
			primPath: parentPath
		) else {
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

private func parentPrimPath(of path: String) -> String? {
	let components = path.split(separator: "/")
	guard components.count > 1 else { return nil }
	return "/" + components.dropLast().joined(separator: "/")
}

private func resolvedMaterialBindingPrimPath(from selectedPrimPath: String, nodes: [SceneNode]) -> String {
	guard let selectedNode = findNode(id: selectedPrimPath, in: nodes) else {
		return selectedPrimPath
	}
	let selectedType = selectedNode.typeName?.lowercased() ?? ""
	guard selectedType.contains("material") || selectedType.contains("shader") else {
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

private enum PrimAttributesLoadCancellationID {
	case load
}

private enum PrimTransformSaveCancellationID {
	case save
}

private enum PrimVariantSelectionCancellationID {
	case apply
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
