import ComposableArchitecture
import SceneGraphFeature
import SceneGraphModels
import SwiftUI

public struct SceneNavigatorView: View {
	@Bindable private var store: StoreOf<SceneGraphFeature>

	public init(store: StoreOf<SceneGraphFeature>) {
		self.store = store
	}

	public var body: some View {
		VStack(spacing: 0) {
			// header
			// Divider()
			content
			Divider()
			footer
		}
	}

	private var header: some View {
		HStack(spacing: 6) {
			Label("Scene", systemImage: "cube.transparent")
				.font(.caption)
			Spacer()
			Button {
				store.send(.refreshRequested)
			} label: {
				Image(systemName: "arrow.clockwise")
			}
			.buttonStyle(.borderless)
			.help("Refresh")
		}
		.padding(.horizontal, 10)
		.padding(.vertical, 6)
	}

	private var content: some View {
		ZStack {
			List(selection: $store.selectedNodeID) {
				OutlineGroup(
					filteredNodes(store.nodes, filterText: store.filterText),
					children: \.childrenOptional
				) { node in
					SceneNavigatorRow(node: node)
				}
			}
			.listStyle(.inset)

			if store.isLoading && store.nodes.isEmpty {
				ProgressView("Loading Scene...")
					.font(.caption)
					.padding()
			}

			if let error = store.errorMessage, store.nodes.isEmpty {
				Text(error)
					.font(.caption)
					.foregroundStyle(.secondary)
					.padding()
			}
		}
	}

	private var footer: some View {
		HStack(spacing: 8) {
			Button {
			} label: {
				Image(systemName: "plus")
			}
			.buttonStyle(.borderless)
			.disabled(true)

			TextField("Filter", text: $store.filterText)
				.textFieldStyle(.roundedBorder)
		}
		.padding(8)
	}
}

private struct SceneNavigatorRow: View {
	let node: SceneNode

	var body: some View {
		HStack(spacing: 6) {
			Image(systemName: iconName(for: node))
				.font(.caption)
			Text(node.displayName)
				.lineLimit(1)
			if let typeName = node.typeName {
				Text(typeName)
					.font(.caption2)
					.foregroundStyle(.secondary)
			}
		}
		.padding(.vertical, 2)
		.listRowSeparator(.hidden)
	}

	private func iconName(for node: SceneNode) -> String {
		if let type = node.typeName?.lowercased() {
			if type.contains("material") { return "paintbrush" }
			if type.contains("shader") { return "lines.measurement.horizontal" }
			if type.contains("light") { return "lightbulb" }
			if type.contains("camera") { return "camera" }
			if type.contains("sphere") { return "circle" }
		}
		return "cube"
	}
}

private func filteredNodes(_ nodes: [SceneNode], filterText: String)
	-> [SceneNode]
{
	let trimmed = filterText.trimmingCharacters(in: .whitespacesAndNewlines)
	guard !trimmed.isEmpty else { return nodes }
	let query = trimmed.lowercased()
	return nodes.compactMap { node in
		let filteredChildren = filteredNodes(node.children, filterText: query)
		let matchesName = node.name.lowercased().contains(query)
		let matchesType = node.typeName?.lowercased().contains(query) ?? false
		if matchesName || matchesType || !filteredChildren.isEmpty {
			return SceneNode(
				id: node.id,
				name: node.name,
				typeName: node.typeName,
				specifier: node.specifier,
				path: node.path,
				children: filteredChildren
			)
		}
		return nil
	}
}

extension SceneNode {
	fileprivate var childrenOptional: [SceneNode]? {
		children.isEmpty ? nil : children
	}
}
