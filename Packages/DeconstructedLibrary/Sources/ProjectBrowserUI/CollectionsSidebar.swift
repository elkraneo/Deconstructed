import ComposableArchitecture
import DeconstructedModels
import ProjectBrowserFeature
import ProjectBrowserModels
import SwiftUI
import UniformTypeIdentifiers

struct CollectionsSidebar: View {
	@Bindable var store: StoreOf<ProjectBrowserFeature>

	var body: some View {
		List {
			Section("Collections") {
				Label("All Files", systemImage: DeconstructedConstants.SFSymbol.docOnDoc)
			}

			Section("Project") {
				if let rkassetsRoot = store.assetItems.first(where: {
					$0.url.isRKAssets && $0.isDirectory
				}) {
					ProjectSidebarNode(item: rkassetsRoot, store: store)
				}
			}
		}
		.listStyle(.sidebar)
	}
}

private struct ProjectSidebarNode: View {
	let item: AssetItem
	@Bindable var store: StoreOf<ProjectBrowserFeature>

	var body: some View {
		if item.isDirectory {
			DisclosureGroup(isExpanded: expandedBinding(for: item.id)) {
				ForEach(item.children ?? []) { child in
					ProjectSidebarNode(item: child, store: store)
				}
			} label: {
				ProjectSidebarRow(item: item, store: store)
			}
		} else {
			ProjectSidebarRow(item: item, store: store)
		}
	}

	private func expandedBinding(for id: AssetItem.ID) -> Binding<Bool> {
		Binding(
			get: { store.expandedDirectories.contains(id) },
			set: { isExpanded in
				if isExpanded {
					store.expandedDirectories.insert(id)
				} else {
					store.expandedDirectories.remove(id)
				}
			}
		)
	}
}

private struct ProjectSidebarRow: View {
	let item: AssetItem
	@Bindable var store: StoreOf<ProjectBrowserFeature>
	@State private var isDropTarget = false
	private let dropTypes: [String] = [
		UTType.text.identifier,
		UTType.plainText.identifier,
		UTType.utf8PlainText.identifier,
		UTType.utf16PlainText.identifier
	]

	var body: some View {
		Label(item.name, systemImage: item.fileType.iconName)
			.foregroundStyle(.orange)
			.contentShape(Rectangle())
			.onDrag {
				store.send(.dragStarted([item.id]))
				return NSItemProvider(object: item.id.uuidString as NSString)
			}
			.onTapGesture {
				if item.isDirectory {
					store.send(.setCurrentDirectory(item.id))
				}
			}
			.onDrop(of: dropTypes, isTargeted: $isDropTarget) { _ in
				guard item.isDirectory else { return false }
				let ids = store.draggingItemIds
				guard !ids.isEmpty else { return false }
				store.send(.moveItems(ids, to: item.id))
				store.send(.dragEnded)
				return true
			}
			.listRowBackground(backgroundColor)
	}

	private var backgroundColor: Color {
		if isDropTarget {
			return Color.accentColor.opacity(0.12)
		}
		if item.isDirectory, store.currentDirectoryId == item.id {
			return Color.accentColor.opacity(0.18)
		}
		return Color.clear
	}

}
