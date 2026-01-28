import ComposableArchitecture
import DeconstructedClients
import Foundation

@Reducer
public struct AppFeature {
	public init() {}

	/// App-level responsibilities:
	/// - Welcome window presentation and lifecycle
	/// - Recent projects list and refresh
	/// - New project creation flow
	/// - App-scoped commands and global shortcuts
	@ObservableState
	public struct State: Equatable {
		public var recentProjects: [URL] = []

		public init(recentProjects: [URL] = []) {
			self.recentProjects = recentProjects
		}
	}

	public enum Action: Equatable {
		case onAppear
		case refreshRecentProjects
		case recentProjectsResponse([URL])
		case newProjectButtonTapped
	}

	@Dependency(\.recentDocuments) private var recentDocuments
	@Dependency(\.newProjectClient) private var newProjectClient

	public var body: some Reducer<State, Action> {
		Reduce { state, action in
			switch action {
			case .onAppear, .refreshRecentProjects:
				let recentDocuments = self.recentDocuments
				return .run { send in
					let urls = await MainActor.run {
						recentDocuments.fetch()
					}
					await send(.recentProjectsResponse(urls))
				}

			case let .recentProjectsResponse(urls):
				state.recentProjects = urls
				return .none

			case .newProjectButtonTapped:
				let newProjectClient = self.newProjectClient
				return .run { _ in
					await newProjectClient.create()
				}
			}
		}
	}
}
