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
			if store.filterText.isEmpty {
				return true
			}
			return item.name.localizedCaseInsensitiveContains(store.filterText)
		}

		if let filterType = store.filterFileType {
			items = items.filter { !$0.isDirectory && $0.fileType == filterType }
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
					}
				}
			}
			.padding()
		}
		.background(.windowBackground)
	}
}
