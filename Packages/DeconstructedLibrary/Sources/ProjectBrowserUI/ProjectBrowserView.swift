import ComposableArchitecture
import ProjectBrowserFeature
import ProjectBrowserModels
import SwiftUI

public struct ProjectBrowserView: View {
	@Bindable var store: StoreOf<ProjectBrowserFeature>
	let onOpenURL: ((URL) -> Void)?

	public init(store: StoreOf<ProjectBrowserFeature>, onOpenURL: ((URL) -> Void)? = nil) {
		self.store = store
		self.onOpenURL = onOpenURL
	}

	public var body: some View {
		HSplitView {
			// Sidebar - Collections
			CollectionsSidebar(store: store)
				.frame(minWidth: 140, idealWidth: 180, maxWidth: 300)

			// Content Area
			VStack(spacing: 0) {
				BrowserToolbar(store: store)
				Divider()
				if store.isLoading {
					ProgressView("Loading assets…")
						.frame(maxWidth: .infinity, maxHeight: .infinity)
				} else if let error = store.errorMessage {
					ContentUnavailableView(
						"Failed to Load",
						systemImage: "exclamationmark.triangle",
						description: Text(error)
					)
				} else if store.assetItems.isEmpty {
					ContentUnavailableView(
						"No Assets",
						systemImage: "folder",
						description: Text("Open a .realitycomposerpro project to browse assets.")
					)
				} else {
					AssetGridView(store: store, onOpenURL: onOpenURL)
				}
			}

			// Inspector (optional, shown when item selected)
			if !store.selectedItems.isEmpty {
				AssetInspectorView(store: store)
					.frame(minWidth: 200, idealWidth: 260)
			}
		}
		.task {
			await store.send(.onAppear).finish()
		}
	}
}
