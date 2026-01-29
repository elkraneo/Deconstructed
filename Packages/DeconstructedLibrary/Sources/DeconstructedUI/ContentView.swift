import ComposableArchitecture
import DeconstructedFeatures
import DeconstructedModels
import Foundation
import ProjectBrowserFeature
import ProjectBrowserUI
import RCPDocument
import SwiftUI
import ViewportUI
import ViewportModels

public struct ContentView: View {
	@Binding public var document: DeconstructedDocument
	@State private var store: StoreOf<DocumentEditorFeature>?

	public init(document: Binding<DeconstructedDocument>) {
		self._document = document
	}

	public var body: some View {
		VStack(spacing: 0) {
			// Top: Viewport (if a scene is open)
			viewportArea
			
			// Middle: Divider with tab bar
			editorPanelArea
		}
		.onAppear {
			if store == nil {
				store = Store(initialState: DocumentEditorFeature.State()) {
					DocumentEditorFeature()
				}
			}
		}
		.onChange(of: document.documentURL) { oldUrl, newUrl in
			if let newUrl, let store {
				store.send(.projectBrowser(.loadAssets(documentURL: newUrl)))
				store.send(.documentOpened(newUrl))
			}
		}
		.task {
			if let url = document.documentURL, let store {
				store.send(.projectBrowser(.loadAssets(documentURL: url)))
				store.send(.documentOpened(url))
			}
		}
	}
	
	// MARK: - Viewport Area (Top)
	
	@ViewBuilder
	private var viewportArea: some View {
		if let store {
			VStack(spacing: 0) {
				// Scene tabs at the top of viewport
				if !store.openScenes.isEmpty {
					ScrollView(.horizontal, showsIndicators: false) {
						HStack(spacing: 0) {
							ForEach(store.openScenes) { scene in
								TabButton(
									label: scene.displayName,
									icon: "cube.transparent",
									isSelected: store.selectedTab == .scene(id: scene.id),
									canClose: true,
									onSelect: {
										store.send(.tabSelected(.scene(id: scene.id)))
									},
									onClose: {
										store.send(.sceneClosed(scene.id))
									}
								)
							}
						}
						.padding(.horizontal, 8)
						.padding(.vertical, 4)
					}
					.background(.ultraThinMaterial)
					Divider()
				}
				
				// Viewport content
				Group {
					if case .scene(let id) = store.selectedTab,
					   let sceneTab = store.openScenes[id: id] {
						ViewportView(
							modelURL: sceneTab.fileURL,
							configuration: ViewportConfiguration(showGrid: true, showAxes: true),
							onCameraStateChanged: { transform in
								store.send(.sceneCameraChanged(sceneTab.fileURL, transform))
							},
							initialCameraTransform: sceneTab.cameraTransform
						)
						.id(sceneTab.fileURL)
					} else if !store.openScenes.isEmpty {
						// Show first scene if none selected but some are open
						if let firstScene = store.openScenes.first {
							ViewportView(
								modelURL: firstScene.fileURL,
								configuration: ViewportConfiguration(showGrid: true, showAxes: true),
								onCameraStateChanged: { transform in
									store.send(.sceneCameraChanged(firstScene.fileURL, transform))
								},
								initialCameraTransform: firstScene.cameraTransform
							)
							.id(firstScene.fileURL)
						}
					} else {
						// No scene open - show placeholder
						ContentUnavailableView(
							"No Scene Open",
							systemImage: "cube.transparent",
							description: Text("Double-click a .usda file in the Project Browser to open it.")
						)
					}
				}
			}
		} else {
			ContentUnavailableView(
				"Loading...",
				systemImage: "arrow.triangle.2.circlepath"
			)
		}
	}
	
	// MARK: - Editor Panel Area (Bottom with Tabs)
	
	@ViewBuilder
	private var editorPanelArea: some View {
		if let store {
			VStack(spacing: 0) {
				// Tab bar
				ScrollView(.horizontal, showsIndicators: false) {
					HStack(spacing: 0) {
						// Fixed editor tabs
					TabButton(
						label: "Project Browser",
						icon: "square.grid.2x2",
						isSelected: store.selectedBottomTab == .projectBrowser,
						canClose: false
					) {
						store.send(.bottomTabSelected(.projectBrowser))
					}
					
					TabButton(
						label: "Debug",
						icon: "ladybug",
						isSelected: store.selectedBottomTab == .debug,
						canClose: false
					) {
						store.send(.bottomTabSelected(.debug))
					}
					}
					.padding(.horizontal, 8)
					.padding(.vertical, 4)
				}
				.background(.ultraThinMaterial)
				
				Divider()
				
			// Editor content
			switch store.selectedBottomTab {
			case .projectBrowser:
				ProjectBrowserView(
					store: store.scope(state: \.projectBrowser, action: \.projectBrowser),
					onOpenURL: { url in
						store.send(.sceneOpened(url))
					}
				)
				.frame(minHeight: 200, idealHeight: 300)
				
			case .debug:
				DebugFileStructureView(document: document)
				.frame(minHeight: 200, idealHeight: 300)
				
			case .shaderGraph, .timeline, .audio, .statistics:
				ContentUnavailableView(
					store.selectedBottomTab.displayName,
					systemImage: store.selectedBottomTab.icon,
					description: Text("This editor is not yet implemented.")
				)
				.frame(minHeight: 200, idealHeight: 300)
			}
			}
			.frame(maxHeight: .infinity, alignment: .bottom)
		}
	}
}

// MARK: - Tab Button

private struct TabButton: View {
	let label: String
	let icon: String
	let isSelected: Bool
	let canClose: Bool
	let onSelect: () -> Void
	var onClose: (() -> Void)? = nil
	
	var body: some View {
		Button(action: onSelect) {
			HStack(spacing: 4) {
				Image(systemName: icon)
					.font(.caption)
				Text(label)
					.font(.caption)
					.lineLimit(1)
				
				if canClose {
					Button(action: { onClose?() }) {
						Image(systemName: "xmark")
							.font(.caption2)
							.foregroundStyle(.secondary)
					}
					.buttonStyle(.plain)
				}
			}
			.padding(.horizontal, 8)
			.padding(.vertical, 4)
			.background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
			.cornerRadius(4)
		}
		.buttonStyle(.plain)
	}
}

// MARK: - Debug View

private struct DebugFileStructureView: View {
	let document: DeconstructedDocument

	var body: some View {
		NavigationSplitView {
			List {
				if let contents = document.bundle.fileWrappers {
					ForEach(contents.keys.sorted(), id: \.self) { key in
						if let wrapper = contents[key] {
							FileWrapperRow(name: key, wrapper: wrapper)
						}
					}
				}
			}
			.listStyle(.sidebar)
			.navigationSplitViewColumnWidth(min: 200, ideal: 250)
		} detail: {
			ScrollView([.vertical, .horizontal]) {
				VStack(spacing: 16) {
					if let projectData = document.parsedProjectData {
						GroupBox("Project Info") {
							LabeledContent("Project ID", value: String(projectData.projectID))
							LabeledContent("Scenes", value: "\(projectData.uniqueSceneCount)")
						}

						if !projectData.normalizedScenePaths.isEmpty {
							GroupBox("Scene Paths") {
								ForEach(
									Array(projectData.normalizedScenePaths.keys.sorted()),
									id: \.self
								) { path in
									LabeledContent(
										path,
										value: projectData.normalizedScenePaths[path] ?? ""
									)
									.font(.caption)
								}
							}
						}

						if let documentURL = document.documentURL {
							SceneConsistencyView(documentURL: documentURL, projectData: projectData)
						}
					} else {
						ContentUnavailableView(
							"No Project Data",
							systemImage: "doc.questionmark",
							description: Text("Could not parse ProjectData/main.json")
						)
					}
				}
				.padding()
				.frame(maxWidth: .infinity, alignment: .topLeading)
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
		}
	}
}

private struct SceneConsistencyView: View {
	let documentURL: URL
	let projectData: RCPProjectData

	var body: some View {
		let report = SceneConsistencyReport(documentURL: documentURL, projectData: projectData)
		GroupBox("Scene Consistency") {
			VStack(alignment: .leading, spacing: 8) {
				LabeledContent("Indexed Scenes", value: "\(report.indexedPaths.count)")
				LabeledContent("Files On Disk", value: "\(report.diskPaths.count)")
				LabeledContent("Missing On Disk", value: "\(report.missingOnDisk.count)")
				LabeledContent("Unindexed On Disk", value: "\(report.unindexedOnDisk.count)")

				if !report.missingOnDisk.isEmpty {
					Divider()
					Text("Missing On Disk")
						.font(.caption)
						.foregroundStyle(.secondary)
					ForEach(report.missingOnDisk.sorted(), id: \.self) { path in
						Text(path)
							.font(.caption2)
							.foregroundStyle(.secondary)
					}
				}

				if !report.unindexedOnDisk.isEmpty {
					Divider()
					Text("Unindexed On Disk")
						.font(.caption)
						.foregroundStyle(.secondary)
					ForEach(report.unindexedOnDisk.sorted(), id: \.self) { path in
						Text(path)
							.font(.caption2)
							.foregroundStyle(.secondary)
					}
				}
			}
		}
	}
}

private struct SceneConsistencyReport {
	let indexedPaths: Set<String>
	let diskPaths: Set<String>
	let missingOnDisk: Set<String>
	let unindexedOnDisk: Set<String>

	init(documentURL: URL, projectData: RCPProjectData) {
		let rootURL = documentURL.deletingLastPathComponent()
		indexedPaths = Set(projectData.pathsToIds.keys.compactMap { normalizedScenePath($0) })
		diskPaths = Set(sceneFilesOnDisk(documentURL: documentURL, projectData: projectData).compactMap {
			relativePath(from: rootURL, to: $0)
		})
		missingOnDisk = indexedPaths.subtracting(diskPaths)
		unindexedOnDisk = diskPaths.subtracting(indexedPaths)
	}
}

private func sceneFilesOnDisk(documentURL: URL, projectData: RCPProjectData) -> [URL] {
	let rootURL = documentURL.deletingLastPathComponent()
	guard let projectName = projectName(from: projectData) else {
		return []
	}
	let rkassetsURL = rootURL
		.appendingPathComponent("Sources")
		.appendingPathComponent(projectName)
		.appendingPathComponent("\(projectName).rkassets")
	let fileManager = FileManager.default
	guard let enumerator = fileManager.enumerator(
		at: rkassetsURL,
		includingPropertiesForKeys: [.isDirectoryKey],
		options: [.skipsHiddenFiles]
	) else {
		return []
	}

	var result: [URL] = []
	for case let url as URL in enumerator {
		if url.pathExtension.lowercased() == "usda" {
			result.append(url)
		}
	}
	return result
}

private func projectName(from projectData: RCPProjectData) -> String? {
	guard let firstPath = projectData.pathsToIds.keys.sorted().first,
	      let normalized = normalizedScenePath(firstPath) else {
		return nil
	}
	let components = normalized.split(separator: "/").map { String($0) }
	guard components.count >= 4 else {
		return nil
	}
	return components[0]
}

private func normalizedScenePath(_ path: String) -> String? {
	let components = path
		.split(separator: "/")
		.map { String($0) }
		.map { $0.removingPercentEncoding ?? $0 }
	guard !components.isEmpty else { return nil }
	return components.joined(separator: "/")
}

private func relativePath(from rootURL: URL, to fileURL: URL) -> String? {
	let rootComponents = rootURL.standardizedFileURL.pathComponents
	let fileComponents = fileURL.standardizedFileURL.pathComponents
	guard fileComponents.starts(with: rootComponents) else {
		return nil
	}
	return Array(fileComponents.dropFirst(rootComponents.count)).joined(separator: "/")
}

struct FileWrapperRow: View {
	let name: String
	let wrapper: FileWrapper

	var body: some View {
		if wrapper.isDirectory {
			DisclosureGroup {
				if let children = wrapper.fileWrappers {
					ForEach(children.keys.sorted(), id: \.self) { childKey in
						if let child = children[childKey] {
							FileWrapperRow(name: childKey, wrapper: child)
						}
					}
				}
			} label: {
				Label(name, systemImage: folderIcon)
			}
		} else {
			Label(name, systemImage: fileIcon)
				.foregroundStyle(.secondary)
		}
	}

	private var folderIcon: String {
		if name.hasSuffix(".rkassets") {
			return "cube.fill"
		} else if name.hasSuffix(".realitycomposerpro") {
			return "shippingbox.fill"
		}
		return "folder.fill"
	}

	private var fileIcon: String {
		if name.hasSuffix(".json") || name.hasSuffix(".rcprojectdata") {
			return "doc.text.fill"
		} else if name.hasSuffix(".swift") {
			return "swift"
		} else if name.hasSuffix(".usda") || name.hasSuffix(".usd") {
			return "cube.transparent"
		}
		return "doc.fill"
	}
}

#Preview {
	ContentView(document: .constant(DeconstructedDocument()))
}
