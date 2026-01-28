import ProjectBrowserModels
import SwiftUI

struct AssetGridItem: View {
	let item: AssetItem
	let iconSize: CGFloat
	let isSelected: Bool
	let isRenaming: Bool
	@State private var editingName: String = ""

	var body: some View {
		VStack(spacing: 8) {
			// Icon / Thumbnail
			AssetThumbnail(item: item, size: iconSize)
				.overlay {
					if isSelected {
						RoundedRectangle(cornerRadius: 8)
							.stroke(Color.accentColor, lineWidth: 3)
					}
				}

			// Name Label
			if isRenaming {
				TextField("Name", text: $editingName)
					.textFieldStyle(.plain)
					.multilineTextAlignment(.center)
					.onAppear { editingName = item.name }
			} else {
				Text(item.name)
					.font(.caption)
					.lineLimit(2)
					.multilineTextAlignment(.center)
			}
		}
		.frame(width: iconSize + 20)
		.padding(8)
		.background(isSelected ? Color.accentColor.opacity(0.1) : .clear)
		.clipShape(RoundedRectangle(cornerRadius: 8))
	}
}
