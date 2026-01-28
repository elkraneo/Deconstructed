import ComposableArchitecture
import ProjectBrowserFeature
import ProjectBrowserModels
import SwiftUI

struct AssetInspectorView: View {
	@Bindable var store: StoreOf<ProjectBrowserFeature>

	private var selectedItem: AssetItem? {
		guard let id = store.selectedItems.first else { return nil }
		return store.assetItems.first { $0.id == id }
	}

	var body: some View {
		Group {
			if let item = selectedItem {
				VStack(alignment: .leading, spacing: 12) {
					Text("Properties")
						.font(.headline)

					Divider()

					PropertyRow("Name", value: item.name)
					PropertyRow("Type", value: item.fileType.displayName)
					PropertyRow("Kind", value: item.isDirectory ? "Folder" : "File")

					if !item.isDirectory {
						PropertyRow("Extension", value: item.url.pathExtension)
					}

					PropertyRow("Path", value: item.url.path)

					if let uuid = item.sceneUUID {
						PropertyRow("Scene UUID", value: uuid)
					}

					Spacer()
				}
				.padding()
			} else {
				ContentPlaceholderView()
			}
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
	}
}

struct PropertyRow: View {
	let label: String
	let value: String
	
	init(_ label: String, value: String) {
		self.label = label
		self.value = value
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 2) {
			Text(label)
				.font(.caption)
				.foregroundStyle(.secondary)
			Text(value)
				.font(.body)
				.textSelection(.enabled)
		}
	}
}

struct ContentPlaceholderView: View {
	var body: some View {
		VStack(spacing: 8) {
			Image(systemName: "info.circle")
				.font(.largeTitle)
				.foregroundStyle(.secondary)
			Text("Select a file to view its properties")
				.font(.caption)
				.foregroundStyle(.secondary)
		}
	}
}
