import ComposableArchitecture
import ProjectBrowserFeature
import ProjectBrowserModels
import SwiftUI
import UniformTypeIdentifiers

struct CollectionsSidebar: View {
	@Bindable var store: StoreOf<ProjectBrowserFeature>

	var body: some View {
		List {
			Section("Collections") {
				Label("All Files", systemImage: "doc.on.doc")
			}

			Section("Project") {
				if let rkassetsRoot = store.assetItems.first(where: {
					$0.url.path.contains(".rkassets") && $0.isDirectory
				}) {
					OutlineGroup([rkassetsRoot], children: \.children) { item in
						ProjectSidebarRow(item: item, store: store)
					}
				}
			}
		}
		.listStyle(.sidebar)
	}
}

private struct ProjectSidebarRow: View {
	let item: AssetItem
	@Bindable var store: StoreOf<ProjectBrowserFeature>

	var body: some View {
		Label(item.name, systemImage: item.fileType.iconName)
			.foregroundStyle(.orange)
			.onDrop(of: [UTType.plainText.identifier], isTargeted: nil) { providers in
				guard item.isDirectory else {
					return false
				}
				handleDrop(providers: providers, destinationID: item.id)
				return true
			}
	}

	private func handleDrop(providers: [NSItemProvider], destinationID: AssetItem.ID) {
		for provider in providers {
			if provider.canLoadObject(ofClass: NSString.self) {
				_ = provider.loadObject(ofClass: NSString.self) { object, _ in
					guard let object = object as? NSString else { return }
					let string = String(object)
					if let id = UUID(uuidString: string) {
						Task { @MainActor in
							store.send(.moveItems([id], to: destinationID))
						}
					}
				}
				break
			}
		}
	}
}
