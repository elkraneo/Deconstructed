import ComposableArchitecture
import SwiftUI

/// Wrapper to handle document environment actions
public struct WelcomeWindowContent: View {
	@Environment(\.dismissWindow) private var dismissWindow
	@Environment(\.openDocument) private var openDocument
	private let store: StoreOf<AppFeature>

	public init(store: StoreOf<AppFeature>) {
		self.store = store
	}

	public var body: some View {
		LaunchExperience(
			store: store,
			onNewProject: {
				dismissWindow(id: "welcome")
			},
			onOpenProject: { url in
				dismissWindow(id: "welcome")
				Task {
					try? await openDocument(at: url)
				}
			}
		)
	}
}
