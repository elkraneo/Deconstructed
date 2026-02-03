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
		public var sceneNodes: [SceneNode]
		public var isLoading: Bool
		public var errorMessage: String?

		public init(
			sceneURL: URL? = nil,
			selectedNodeID: SceneNode.ID? = nil,
			layerData: SceneLayerData? = nil,
			sceneNodes: [SceneNode] = [],
			isLoading: Bool = false,
			errorMessage: String? = nil
		) {
			self.sceneURL = sceneURL
			self.selectedNodeID = selectedNodeID
			self.layerData = layerData
			self.sceneNodes = sceneNodes
			self.isLoading = isLoading
			self.errorMessage = errorMessage
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

	public enum Action: Equatable, BindableAction {
		case binding(BindingAction<State>)
		case sceneURLChanged(URL?)
		case selectionChanged(SceneNode.ID?)
		case sceneGraphUpdated([SceneNode])
		case layerDataLoaded(SceneLayerData)
		case layerDataLoadFailed(String)
		case refreshLayerData

		case defaultPrimChanged(String)
		case metersPerUnitChanged(Double)
		case upAxisChanged(UpAxis)
		case convertVariantsToConfigurationsTapped

		case layerDataUpdateSucceeded
		case layerDataUpdateFailed(String)
	}

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
				state.sceneNodes = []
				guard let url else {
					state.isLoading = false
					return .none
				}
				state.isLoading = true
				return .run { send in
					await loadLayerData(url: url, send: send)
				}

			case let .selectionChanged(nodeID):
				state.selectedNodeID = nodeID
				return .none

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

			case let .layerDataLoaded(data):
				print("[InspectorFeature] layerDataLoaded: defaultPrim=\(data.defaultPrim ?? "nil"), mpu=\(data.metersPerUnit), upAxis=\(data.upAxis)")
				var layerData = data
				// If we have scene nodes, use them to populate availablePrims
				if !state.sceneNodes.isEmpty {
					layerData.availablePrims = extractAvailablePrims(from: state.sceneNodes)
					print("[InspectorFeature] Applied \(layerData.availablePrims.count) prims from scene nodes")
				}
				state.layerData = layerData
				state.isLoading = false
				state.errorMessage = nil
				return .none

			case let .layerDataLoadFailed(message):
				state.errorMessage = message
				state.isLoading = false
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

	print("[InspectorFeature] Sending layerDataLoaded")
	await send(.layerDataLoaded(layerData))
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
