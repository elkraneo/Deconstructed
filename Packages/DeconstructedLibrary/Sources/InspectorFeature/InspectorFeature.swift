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
		public var layerData: SceneLayerData?
		public var playbackData: ScenePlaybackData?
		public var primAttributes: USDPrimAttributes?
		public var primTransform: USDTransformData?
		public var sceneNodes: [SceneNode]
		public var isLoading: Bool
		public var errorMessage: String?
		public var primIsLoading: Bool
		public var primErrorMessage: String?
		public var playbackIsPlaying: Bool
		public var playbackCurrentTime: Double
		public var playbackSpeed: Double
		public var playbackIsScrubbing: Bool

		public init(
			sceneURL: URL? = nil,
			selectedNodeID: SceneNode.ID? = nil,
			layerData: SceneLayerData? = nil,
			playbackData: ScenePlaybackData? = nil,
			primAttributes: USDPrimAttributes? = nil,
			primTransform: USDTransformData? = nil,
			sceneNodes: [SceneNode] = [],
			isLoading: Bool = false,
			errorMessage: String? = nil,
			primIsLoading: Bool = false,
			primErrorMessage: String? = nil,
			playbackIsPlaying: Bool = false,
			playbackCurrentTime: Double = 0,
			playbackSpeed: Double = 1.0,
			playbackIsScrubbing: Bool = false
		) {
			self.sceneURL = sceneURL
			self.selectedNodeID = selectedNodeID
			self.layerData = layerData
			self.playbackData = playbackData
			self.primAttributes = primAttributes
			self.primTransform = primTransform
			self.sceneNodes = sceneNodes
			self.isLoading = isLoading
			self.errorMessage = errorMessage
			self.primIsLoading = primIsLoading
			self.primErrorMessage = primErrorMessage
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
				state.errorMessage = nil
				state.layerData = nil
				state.playbackData = nil
				state.primAttributes = nil
				state.primTransform = nil
				state.primIsLoading = false
				state.primErrorMessage = nil
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
					.cancel(id: PlaybackTimerID.playback)
				)

			case let .selectionChanged(nodeID):
				state.selectedNodeID = nodeID
				state.primAttributes = nil
				state.primTransform = nil
				state.primErrorMessage = nil
				guard let nodeID, let url = state.sceneURL else {
					state.primIsLoading = false
					return .none
				}
				state.primIsLoading = true
				return .run { send in
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
				}
				.cancellable(
					id: PrimAttributesLoadCancellationID.load,
					cancelInFlight: true
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
				state.primIsLoading = false
				state.primErrorMessage = nil
				return .none

			case let .primAttributesLoadFailed(message):
				state.primAttributes = nil
				state.primIsLoading = false
				state.primErrorMessage = message
				return .none

			case let .primTransformLoaded(transform):
				state.primTransform = transform
				state.primIsLoading = false
				state.primErrorMessage = nil
				return .none

			case let .primTransformLoadFailed(message):
				state.primTransform = nil
				state.primIsLoading = false
				state.primErrorMessage = message
				return .none

			case let .primTransformChanged(transform):
				guard let url = state.sceneURL,
				      let primPath = state.selectedNodeID else {
					return .none
				}
				state.primTransform = transform
				state.primErrorMessage = nil
				return .run { send in
					do {
						try DeconstructedUSDInterop.setPrimTransform(
							url: url,
							primPath: primPath,
							transform: transform
						)
						await send(.primTransformSaveSucceeded)
					} catch {
						if let refreshed = DeconstructedUSDInterop.getPrimTransform(
							url: url,
							primPath: primPath
						) {
							await send(.primTransformLoaded(refreshed))
						}
						await send(.primTransformSaveFailed(error.localizedDescription))
					}
				}

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

private enum PrimAttributesLoadCancellationID {
	case load
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
