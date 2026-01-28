import ComposableArchitecture
import ProjectBrowserFeature
import ProjectBrowserModels
import SwiftUI

struct BrowserToolbar: View {
	@Bindable var store: StoreOf<ProjectBrowserFeature>

	var body: some View {
		HStack(spacing: 12) {
			// Primary actions (RCP-aligned)
			ControlGroup {
				Button {
					store.send(.importContentTapped)
				} label: {
					Label("Import Content", systemImage: "square.and.arrow.down")
				}
				.help("Import content into the project")
				
				Button {
					store.send(.createFolderTapped)
				} label: {
					Label("New Folder", systemImage: "folder.badge.plus")
				}
				.help("Create new folder in the project")
				
				Button {
					store.send(.createSceneTapped)
				} label: {
					Label("New Scene", image: "custom.cube.transparent.badge.plus")
				}
				.help("Create new scene in the project")
			}
			.labelsHidden()

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
			.disabled(true)
		}
		.padding(.horizontal)
		.padding(.vertical, 8)
	}
}
