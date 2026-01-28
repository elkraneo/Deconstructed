import ComposableArchitecture
import ProjectBrowserFeature
import ProjectBrowserModels
import SwiftUI

public struct ProjectBrowserView: View {
	@Bindable var store: StoreOf<ProjectBrowserFeature>

	public init(store: StoreOf<ProjectBrowserFeature>) {
		self.store = store
	}

	public var body: some View {
		HSplitView {
			// Sidebar - Collections
			CollectionsSidebar(store: store)
				.frame(minWidth: 140, idealWidth: 180)

			// Content Area
			VStack(spacing: 0) {
				BrowserToolbar(store: store)
				Divider()
				AssetGridView(store: store)
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
