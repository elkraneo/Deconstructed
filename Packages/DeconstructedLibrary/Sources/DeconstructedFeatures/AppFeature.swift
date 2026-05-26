import ComposableArchitecture
import DeconstructedClients
import DeconstructedShellRuntime
import Foundation
import InspectorFeature

@Reducer
public struct AppFeature {
	public init() {
		_ = Self.liveDependenciesInstalled
	}

	/// Installs OpenUSD-backed dependency implementations that live in
	/// `DeconstructedShellRuntime`. Feature targets (e.g. `InspectorFeature`)
	/// declare a safe default `liveValue`; this override swaps in the real
	/// shell-runtime-backed value once the app launches. Computed exactly
	/// once via a static `let` so multiple `AppFeature()` constructions stay
	/// cheap.
	private static let liveDependenciesInstalled: Bool = {
		prepareDependencies {
			$0.sceneInspector = .live
		}
		return true
	}()

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

	public enum Action {
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
