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
		var items = store.assetItems.filter { item in
			if store.filterText.isEmpty {
				return true
			}
			return item.name.localizedCaseInsensitiveContains(store.filterText)
		}

		if let filterType = store.filterFileType {
			items = items.filter { $0.fileType == filterType }
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
						isRenaming: store.renamingItemId == item.id
					)
					.onTapGesture {
						store.send(.itemSelected(item.id))
					}
					.onTapGesture(count: 2) {
						store.send(.itemDoubleClicked(item.id))
					}
				}
			}
			.padding()
		}
		.background(.windowBackground)
	}
}
