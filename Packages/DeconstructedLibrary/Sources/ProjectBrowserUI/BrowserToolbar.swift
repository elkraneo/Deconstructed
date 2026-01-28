import ComposableArchitecture
import ProjectBrowserFeature
import ProjectBrowserModels
import SwiftUI

struct BrowserToolbar: View {
	@Bindable var store: StoreOf<ProjectBrowserFeature>

	var body: some View {
		HStack(spacing: 12) {
			// Add actions
			Button {
				store.send(.createFolderTapped)
			} label: {
				Label("Add", systemImage: "plus")
			}

			Button {
				store.send(.createFolderTapped)
			} label: {
				Label("New Folder", systemImage: "folder.badge.plus")
			}

			Spacer()

			// Icon size slider
			Slider(value: $store.iconSize, in: 40...160)
				.frame(width: 120)

			// Sort controls
			Menu {
				Button("Name") { store.send(.setSortOrder(.name)) }
				Button("Date Modified") { store.send(.setSortOrder(.dateModified)) }
				Button("Type") { store.send(.setSortOrder(.type)) }
			} label: {
				Image(systemName: "arrow.up.arrow.down")
			}

			// Filter
			Menu {
				Button("All Files") { store.send(.setFilterFileType(nil)) }
				ForEach(AssetFileType.browsable, id: \.self) { type in
					Button(type.displayName) { store.send(.setFilterFileType(type)) }
				}
			} label: {
				HStack {
					Image(systemName: "line.3.horizontal.decrease.circle")
					Text("Filter")
				}
			}
		}
		.padding(.horizontal)
		.padding(.vertical, 8)
	}
}
