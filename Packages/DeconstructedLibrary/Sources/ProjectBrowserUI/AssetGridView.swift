import ComposableArchitecture
import ProjectBrowserFeature
import ProjectBrowserModels
import SwiftUI

struct AssetGridView: View {
	@Bindable var store: StoreOf<ProjectBrowserFeature>

	private var columns: [GridItem] {
		[GridItem(.adaptive(minimum: store.iconSize + 20), spacing: 16)]
	}

	private var filteredAndSortedItems: [AssetItem] {
		// Get the root .rkassets directory's children
		guard let rkassetsRoot = store.assetItems.first(where: { $0.url.path.contains(".rkassets") }),
		      let children = rkassetsRoot.children else {
			return []
		}

		var items = children.filter { item in
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
					AssetGridItem(
						item: item,
						iconSize: store.iconSize,
						isSelected: store.selectedItems.contains(item.id),
						isRenaming: store.renamingItemId == item.id,
						onRenameCommit: { newName in
							store.send(.renameItemCommitted(item.id, newName))
						},
						onRenameCancel: {
							store.send(.renameCancelled)
						}
					)
					.onDrag {
						NSItemProvider(object: item.id.uuidString as NSString)
					}
					.onTapGesture {
						store.send(.itemSelected(item.id))
					}
					.onTapGesture(count: 2) {
						store.send(.itemDoubleClicked(item.id))
					}
					.contextMenu {
						Button("Rename") {
							store.send(.itemSelected(item.id))
							store.send(.renameSelectedTapped)
						}
						Button("Move to Folder…") {
							store.send(.itemSelected(item.id))
							store.send(.moveSelectedTapped)
						}
					}
				}
			}
			.padding()
		}
		.background(.windowBackground)
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
