import ComposableArchitecture
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

	public enum Action: Equatable, BindableAction {
		case binding(BindingAction<State>)
		case sceneURLChanged(URL?)
		case sceneGraphLoaded([SceneNode])
		case loadingFailed(String)
		case selectionChanged(SceneNode.ID?)
		case refreshRequested
	}

	@Dependency(\.sceneGraphClient) var sceneGraphClient

	public init() {}

	public var body: some ReducerOf<Self> {
		BindingReducer()

		Reduce { state, action in
			switch action {
			case .binding:
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
						await send(.sceneGraphLoaded(nodes))
					} catch {
						await send(.loadingFailed(error.localizedDescription))
					}
				}

			case let .sceneGraphLoaded(nodes):
				state.nodes = nodes
				state.isLoading = false
				return .none

			case let .loadingFailed(message):
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
						await send(.sceneGraphLoaded(nodes))
					} catch {
						await send(.loadingFailed(error.localizedDescription))
					}
				}
			}
		}
	}
}
