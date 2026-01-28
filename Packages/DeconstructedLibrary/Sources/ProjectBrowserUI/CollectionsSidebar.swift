import ComposableArchitecture
import ProjectBrowserFeature
import ProjectBrowserModels
import SwiftUI

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
						Label(item.name, systemImage: item.fileType.iconName)
							.foregroundStyle(.orange)
					}
				}
			}
		}
		.listStyle(.sidebar)
	}
}
