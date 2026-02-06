import ComposableArchitecture
import DeconstructedUSDInterop
import Foundation
import SceneGraphClients
import SceneGraphModels

@Reducer
public struct SceneGraphFeature {
	@ObservableState
	public struct State: Equatable {
		public var sceneURL: URL?
		public var nodes: [SceneNode]
		public var selectedNodeID: SceneNode.ID?
		public var filterText: String
		public var isLoading: Bool
		public var errorMessage: String?

		public init(
			sceneURL: URL? = nil,
			nodes: [SceneNode] = [],
			selectedNodeID: SceneNode.ID? = nil,
			filterText: String = "",
			isLoading: Bool = false,
			errorMessage: String? = nil
		) {
			self.sceneURL = sceneURL
			self.nodes = nodes
			self.selectedNodeID = selectedNodeID
			self.filterText = filterText
			self.isLoading = isLoading
			self.errorMessage = errorMessage
		}
	}

	public enum Action: BindableAction {
		case binding(BindingAction<State>)
		case sceneURLChanged(URL?)
		case sceneGraphLoaded(URL, [SceneNode])
		case loadingFailed(URL, String)
		case selectionChanged(SceneNode.ID?)
		case refreshRequested

		// Insert actions
		case insertPrimitive(USDPrimitiveType)
		case insertStructural(USDStructuralType)
		case primCreated(String)
		case primCreationFailed(String)
	}

	@Dependency(\.sceneGraphClient) var sceneGraphClient
	@Dependency(\.sceneEditClient) var sceneEditClient

	public init() {}

	public var body: some ReducerOf<Self> {
		BindingReducer()

		Reduce { state, action in
			switch action {
			case let .binding(bindingAction):
				if bindingAction.keyPath == \.selectedNodeID {
					return .send(.selectionChanged(state.selectedNodeID))
				}
				return .none

			case let .sceneURLChanged(url):
				state.sceneURL = url
				state.selectedNodeID = nil
				state.errorMessage = nil
				guard let url else {
					state.nodes = []
					state.isLoading = false
					return .none
				}
				state.isLoading = true
				let sceneGraphClient = self.sceneGraphClient
				return .run { send in
					do {
						let nodes = try await sceneGraphClient.loadSceneGraph(url)
						await send(.sceneGraphLoaded(url, nodes))
					} catch {
						await send(.loadingFailed(url, error.localizedDescription))
					}
				}
				.cancellable(id: SceneGraphLoadCancellationID.load, cancelInFlight: true)

			case let .sceneGraphLoaded(url, nodes):
				guard state.sceneURL == url else {
					return .none
				}
				state.nodes = nodes
				state.isLoading = false
				return .none

			case let .loadingFailed(url, message):
				guard state.sceneURL == url else {
					return .none
				}
				state.errorMessage = message
				state.isLoading = false
				return .none

			case let .selectionChanged(id):
				state.selectedNodeID = id
				return .none

			case .refreshRequested:
				guard let url = state.sceneURL else {
					return .none
				}
				state.isLoading = true
				let sceneGraphClient = self.sceneGraphClient
				return .run { send in
					do {
						let nodes = try await sceneGraphClient.loadSceneGraph(url)
						await send(.sceneGraphLoaded(url, nodes))
					} catch {
						await send(.loadingFailed(url, error.localizedDescription))
					}
				}
				.cancellable(id: SceneGraphLoadCancellationID.load, cancelInFlight: true)

			case let .insertPrimitive(primitiveType):
				guard let url = state.sceneURL else {
					return .none
				}
				// Insert at selected node if it's a container, otherwise at root
				let parentPath = insertionParentPath(
					selectedNodeID: state.selectedNodeID,
					nodes: state.nodes
				)
				let sceneEditClient = self.sceneEditClient
				return .run { send in
					do {
						let createdPath = try await sceneEditClient.createPrimitive(
							url,
							parentPath,
							primitiveType,
							nil
						)
						await send(.primCreated(createdPath))
					} catch {
						await send(.primCreationFailed(error.localizedDescription))
					}
				}

			case let .insertStructural(structuralType):
				guard let url = state.sceneURL else {
					return .none
				}
				let parentPath = insertionParentPath(
					selectedNodeID: state.selectedNodeID,
					nodes: state.nodes
				)
				let sceneEditClient = self.sceneEditClient
				return .run { send in
					do {
						let createdPath = try await sceneEditClient.createStructural(
							url,
							parentPath,
							structuralType,
							nil
						)
						await send(.primCreated(createdPath))
					} catch {
						await send(.primCreationFailed(error.localizedDescription))
					}
				}

			case let .primCreated(path):
				// Select the newly created prim and refresh
				state.selectedNodeID = path
				return .merge(
					.send(.selectionChanged(path)),
					.send(.refreshRequested)
				)

			case let .primCreationFailed(message):
				state.errorMessage = message
				return .none
			}
		}
	}
}

/// Determines the parent path for inserting a new prim.
/// If the selected node is a container type (Xform, Scope), insert as a child.
/// Otherwise, insert at the root level.
private func insertionParentPath(selectedNodeID: SceneNode.ID?, nodes: [SceneNode]) -> String {
	guard let selectedID = selectedNodeID else {
		// No selection - find default prim or use root
		if let defaultPrim = nodes.first {
			return defaultPrim.path
		}
		return "/"
	}

	// Find the selected node and check if it's a container type
	if let node = findNode(id: selectedID, in: nodes) {
		if let typeName = node.typeName?.lowercased(),
		   typeName.contains("xform") || typeName.contains("scope") {
			return node.path
		}
		// For non-container types, use parent path
		let components = node.path.split(separator: "/")
		if components.count > 1 {
			return "/" + components.dropLast().joined(separator: "/")
		}
	}

	// Fallback to root
	if let defaultPrim = nodes.first {
		return defaultPrim.path
	}
	return "/"
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

private enum SceneGraphLoadCancellationID {
	case load
}
