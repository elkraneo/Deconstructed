import ComposableArchitecture
import ProjectBrowserFeature
import ProjectBrowserModels
import SwiftUI

struct AssetGridView: View {
	@Bindable var store: StoreOf<ProjectBrowserFeature>
	let onOpenURL: ((URL) -> Void)?

	private var columns: [GridItem] {
		[GridItem(.adaptive(minimum: store.iconSize + 20), spacing: 16)]
	}

	private var filteredAndSortedItems: [AssetItem] {
		let directoryItems = currentDirectoryChildren()
		guard !directoryItems.isEmpty else {
			return []
		}

		var items = directoryItems.filter { item in
			matchesFilter(item: item, text: store.filterText)
		}

		if let filterType = store.filterFileType {
			items = items.filter { !$0.isDirectory && $0.fileType == filterType }
		}

		items.sort { lhs, rhs in
			sortItems(lhs: lhs, rhs: rhs, order: store.sortOrder, ascending: store.sortAscending)
		}

		return items
	}

	var body: some View {
		ScrollView {
			LazyVGrid(columns: columns, spacing: 16) {
				ForEach(filteredAndSortedItems) { item in
					gridItemView(for: item)
				}
			}
			.padding()
		}
		.background(.windowBackground)
	}
	
	@ViewBuilder
	private func gridItemView(for item: AssetItem) -> some View {
		let isSelected = store.selectedItems.contains(item.id)
		let isRenaming = store.renamingItemId == item.id
		
		AssetGridItem(
			item: item,
			iconSize: store.iconSize,
			isSelected: isSelected,
			isRenaming: isRenaming,
			onRenameCommit: { newName in
				store.send(.renameItemCommitted(item.id, newName))
			},
			onRenameCancel: {
				store.send(.renameCancelled)
			}
		)
		.onDrag {
			makeDragItem(for: item)
		}
		.onDrop(
			of: [.text, .plainText, .utf8PlainText],
			isTargeted: nil
		) { _ in
			handleDrop(on: item)
		}
		.onTapGesture(count: 2) {
			handleDoubleClick(item: item)
		}
		.onTapGesture {
			store.send(.itemSelected(item.id))
		}
		.contextMenu {
			contextMenu(for: item)
		}
	}
	
	private func makeDragItem(for item: AssetItem) -> NSItemProvider {
		let ids: [UUID]
		if store.selectedItems.contains(item.id) {
			ids = Array(store.selectedItems)
		} else {
			ids = [item.id]
		}
		store.send(.dragStarted(ids))
		let payload = ids.map { $0.uuidString }.joined(separator: ",")
		return NSItemProvider(object: payload as NSString)
	}
	
	private func handleDrop(on item: AssetItem) -> Bool {
		guard item.isDirectory else { return false }
		let ids = store.draggingItemIds
		guard !ids.isEmpty else { return false }
		store.send(.moveItems(ids, to: item.id))
		store.send(.dragEnded)
		return true
	}
	
	private func handleDoubleClick(item: AssetItem) {
		store.send(.itemDoubleClicked(item.id))
		if item.isDirectory {
			store.send(.setCurrentDirectory(item.id))
		} else if item.fileType == .usda {
			print("[AssetGridView] Opening USDA file: \(item.url)")
			onOpenURL?(item.url)
		}
	}
	
	@ViewBuilder
	private func contextMenu(for item: AssetItem) -> some View {
		Button("Rename") {
			store.send(.itemSelected(item.id))
			store.send(.renameSelectedTapped)
		}
		Button("Move to Folder…") {
			store.send(.itemSelected(item.id))
			store.send(.moveSelectedTapped)
		}
	}

	private func currentDirectoryChildren() -> [AssetItem] {
		guard let rkassetsRoot = store.assetItems.first(where: { $0.url.path.contains(".rkassets") }) else {
			return []
		}
		guard let currentId = store.currentDirectoryId else {
			return rkassetsRoot.children ?? []
		}
		guard let current = findItem(in: [rkassetsRoot], id: currentId) else {
			return rkassetsRoot.children ?? []
		}
		return current.children ?? []
	}
}

private func matchesFilter(item: AssetItem, text: String) -> Bool {
	guard !text.isEmpty else { return true }
	if item.name.localizedCaseInsensitiveContains(text) {
		return true
	}
	if item.isDirectory, let children = item.children {
		return children.contains { matchesFilter(item: $0, text: text) }
	}
	return false
}

private func sortItems(lhs: AssetItem, rhs: AssetItem, order: BrowserSortOrder, ascending: Bool) -> Bool {
	// Directories first for easier navigation
	if lhs.isDirectory != rhs.isDirectory {
		return lhs.isDirectory
	}

	let comparison: ComparisonResult
	switch order {
	case .name:
		comparison = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
	case .dateModified:
		comparison = lhs.modificationDate.compare(rhs.modificationDate)
	case .type:
		comparison = lhs.fileType.displayName.localizedCaseInsensitiveCompare(rhs.fileType.displayName)
	}

	if ascending {
		return comparison == .orderedAscending
	} else {
		return comparison == .orderedDescending
	}
}

private func findItem(in items: [AssetItem], id: AssetItem.ID) -> AssetItem? {
	AssetItem.find(in: items, id: id)
}
