import ComposableArchitecture
import DeconstructedFeatures
import DeconstructedModels
import Foundation
import InspectorFeature
import InspectorUI
import ProjectBrowserFeature
import ProjectBrowserUI
import RCPDocument
import SceneGraphUI
import SwiftUI
import ViewportModels
import ViewportUI

public struct ContentView: View {
	@Binding public var document: DeconstructedDocument
	@State private var store: StoreOf<DocumentEditorFeature>?

	public init(document: Binding<DeconstructedDocument>) {
		self._document = document
	}

	public var body: some View {
		VSplitView {
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
		.focusedSceneValue(
			\.viewportMenuContext,
			store.map { viewportMenuContext(store: $0) }
		)
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
						let sceneTab = store.openScenes[id: id]
					{
						HStack(spacing: 0) {
							SceneNavigatorView(
								store: store.scope(
									state: \.sceneNavigator,
									action: \.sceneNavigator
								)
							)
							.frame(minWidth: 220, idealWidth: 260, maxWidth: 320)

							Divider()

							ZStack(alignment: .bottomLeading) {
								ViewportView(
									modelURL: sceneTab.fileURL,
									configuration: ViewportConfiguration(
										showGrid: store.viewportShowGrid,
										showAxes: true,
										environment: EnvironmentConfiguration(
											environmentPath: store.environmentPath,
											showBackground: store.environmentShowBackground,
											rotation: store.environmentRotation,
											exposure: store.environmentExposure
										)
									),
									onCameraStateChanged: { transform in
										store.send(.sceneCameraChanged(sceneTab.fileURL, transform))
									},
									cameraTransform: sceneTab.cameraTransform,
									cameraTransformRequestID: sceneTab.cameraTransformRequestID,
									frameRequestID: sceneTab.frameRequestID
								)
								.id(
									"\(sceneTab.fileURL.path)-\(sceneTab.reloadTrigger?.uuidString ?? "initial")"
								)

							ViewportFloatingToolbar(
								context: viewportMenuContext(store: store)
							)
							.padding(12)
						}

						Divider()

						InspectorView(
							store: store.scope(
								state: \.inspector,
								action: \.inspector
							)
						)
						.frame(minWidth: 240, idealWidth: 280, maxWidth: 360)
					}
				} else if !store.openScenes.isEmpty {
						// Show first scene if none selected but some are open
						if let firstScene = store.openScenes.first {
							HStack(spacing: 0) {
								SceneNavigatorView(
									store: store.scope(
										state: \.sceneNavigator,
										action: \.sceneNavigator
									)
								)
								.frame(minWidth: 220, idealWidth: 260, maxWidth: 320)

								Divider()

								ZStack(alignment: .bottomLeading) {
									ViewportView(
										modelURL: firstScene.fileURL,
										configuration: ViewportConfiguration(
											showGrid: store.viewportShowGrid,
											showAxes: true,
											environment: EnvironmentConfiguration(
												environmentPath: store.environmentPath,
												showBackground: store.environmentShowBackground,
												rotation: store.environmentRotation,
												exposure: store.environmentExposure
											)
										),
										onCameraStateChanged: { transform in
											store.send(
												.sceneCameraChanged(firstScene.fileURL, transform)
											)
										},
										cameraTransform: firstScene.cameraTransform,
										cameraTransformRequestID: firstScene
											.cameraTransformRequestID,
										frameRequestID: firstScene.frameRequestID
									)
									.id(
										"\(firstScene.fileURL.path)-\(firstScene.reloadTrigger?.uuidString ?? "initial")"
									)

								ViewportFloatingToolbar(
									context: viewportMenuContext(store: store)
								)
								.padding(12)
							}

							Divider()

							InspectorView(
								store: store.scope(
									state: \.inspector,
									action: \.inspector
								)
							)
							.frame(minWidth: 240, idealWidth: 280, maxWidth: 360)
						}
					}
				} else {
					// No scene open - show placeholder
						ContentUnavailableView(
							"No Scene Open",
							systemImage: DeconstructedConstants.SFSymbol.cubeTransparent,
							description: Text(
								"Double-click a .usda file in the Project Browser to open it."
							)
						)
						.frame(maxWidth: .infinity, maxHeight: .infinity)
					}
				}
			}
		} else {
			ContentUnavailableView(
				"Loading...",
				systemImage: DeconstructedConstants.SFSymbol.arrowTriangle2Circlepath
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
						store: store.scope(
							state: \.projectBrowser,
							action: \.projectBrowser
						),
						onOpenURL: { url in
							store.send(.sceneOpened(url))
						}
					)
					.frame(maxWidth: .infinity, maxHeight: .infinity)
					.frame(minHeight: 200, idealHeight: 300)

				case .debug:
					DebugFileStructureView(document: document)
						.frame(maxWidth: .infinity, maxHeight: .infinity)
						.frame(minHeight: 200, idealHeight: 300)

				case .shaderGraph, .timeline, .audio, .statistics:
					ContentUnavailableView(
						store.selectedBottomTab.displayName,
						systemImage: store.selectedBottomTab.icon,
						description: Text("This editor is not yet implemented.")
					)
					.frame(maxWidth: .infinity, maxHeight: .infinity)
					.frame(minHeight: 200, idealHeight: 300)
				}
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
		}
	}
}

@MainActor
private func viewportMenuContext(store: StoreOf<DocumentEditorFeature>)
	-> ViewportMenuContext
{
	ViewportMenuContext(
		canFrameScene: store.selectedTab != nil,
		canFrameSelected: store.selectedTab != nil,
		isGridVisible: store.viewportShowGrid,
		cameraHistory: store.cameraHistory,
		frameScene: { store.send(.frameSceneRequested) },
		frameSelected: { store.send(.frameSelectedRequested) },
		toggleGrid: { store.send(.toggleGridRequested) },
		selectCameraHistory: { id in store.send(.cameraHistorySelected(id)) },
		canInsert: store.sceneNavigator.sceneURL != nil,
		insertPrimitive: { primitiveType in
			store.send(.sceneNavigator(.insertPrimitive(primitiveType)))
		},
		insertStructural: { structuralType in
			store.send(.sceneNavigator(.insertStructural(structuralType)))
		},
		environmentConfiguration: EnvironmentConfiguration(
			environmentPath: store.environmentPath,
			showBackground: store.environmentShowBackground,
			rotation: store.environmentRotation,
			exposure: store.environmentExposure
		),
		setEnvironmentPath: { path in store.send(.environmentPathChanged(path)) },
		setEnvironmentShowBackground: { show in
			store.send(.environmentShowBackgroundChanged(show))
		},
		setEnvironmentRotation: { rotation in
			store.send(.environmentRotationChanged(rotation))
		},
		setEnvironmentExposure: { exposure in
			store.send(.environmentExposureChanged(exposure))
		}
	)
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
							SceneConsistencyView(
								documentURL: documentURL,
								projectData: projectData
							)
						}
					} else {
						ContentUnavailableView(
							"No Project Data",
							systemImage: DeconstructedConstants.SFSymbol.docQuestionmark,
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
		let report = SceneConsistencyReport(
			documentURL: documentURL,
			projectData: projectData
		)
		GroupBox("Scene Consistency") {
			VStack(alignment: .leading, spacing: 8) {
				LabeledContent("Indexed Scenes", value: "\(report.indexedPaths.count)")
				LabeledContent("Files On Disk", value: "\(report.diskPaths.count)")
				LabeledContent(
					"Missing On Disk",
					value: "\(report.missingOnDisk.count)"
				)
				LabeledContent(
					"Unindexed On Disk",
					value: "\(report.unindexedOnDisk.count)"
				)

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
		indexedPaths = Set(
			projectData.pathsToIds.keys.compactMap { normalizedScenePath($0) }
		)
		diskPaths = Set(
			sceneFilesOnDisk(documentURL: documentURL, projectData: projectData)
				.compactMap {
					relativePath(from: rootURL, to: $0)
				}
		)
		missingOnDisk = indexedPaths.subtracting(diskPaths)
		unindexedOnDisk = diskPaths.subtracting(indexedPaths)
	}
}

private func sceneFilesOnDisk(documentURL: URL, projectData: RCPProjectData)
	-> [URL]
{
	let rootURL = documentURL.deletingLastPathComponent()
	guard let projectName = projectName(from: projectData) else {
		return []
	}
	let rkassetsURL =
		rootURL
		.appendingPathComponent(DeconstructedConstants.DirectoryName.sources)
		.appendingPathComponent(projectName)
		.appendingPathComponent(
			DeconstructedConstants.PathPattern.rkassetsBundle(
				projectName: projectName
			)
		)
	let fileManager = FileManager.default
	guard
		let enumerator = fileManager.enumerator(
			at: rkassetsURL,
			includingPropertiesForKeys: [.isDirectoryKey],
			options: [.skipsHiddenFiles]
		)
	else {
		return []
	}

	var result: [URL] = []
	for case let url as URL in enumerator {
		if url.isUSDFile {
			result.append(url)
		}
	}
	return result
}

private func projectName(from projectData: RCPProjectData) -> String? {
	guard let firstPath = projectData.pathsToIds.keys.sorted().first,
		let normalized = normalizedScenePath(firstPath)
	else {
		return nil
	}
	let components = normalized.split(separator: "/").map { String($0) }
	guard components.count >= 4 else {
		return nil
	}
	return components[0]
}

private func normalizedScenePath(_ path: String) -> String? {
	let components =
		path
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
	return Array(fileComponents.dropFirst(rootComponents.count)).joined(
		separator: "/"
	)
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
		if name.hasSuffix(".\(DeconstructedConstants.FileExtension.rkassets)") {
			return DeconstructedConstants.SFSymbol.cubeFill
		} else if name.hasSuffix(
			".\(DeconstructedConstants.FileExtension.realityComposerPro)"
		) {
			return DeconstructedConstants.SFSymbol.shippingboxFill
		}
		return DeconstructedConstants.SFSymbol.folderFill
	}

	private var fileIcon: String {
		if name.hasSuffix(".\(DeconstructedConstants.FileExtension.json)")
			|| name.hasSuffix(
				".\(DeconstructedConstants.FileExtension.rcprojectdata)"
			)
		{
			return DeconstructedConstants.SFSymbol.docTextFill
		} else if name.hasSuffix(".\(DeconstructedConstants.FileExtension.swift)") {
			return DeconstructedConstants.SFSymbol.swift
		} else if name.hasSuffix(".\(DeconstructedConstants.FileExtension.usda)")
			|| name.hasSuffix(".\(DeconstructedConstants.FileExtension.usd)")
		{
			return DeconstructedConstants.SFSymbol.cubeTransparent
		}
		return DeconstructedConstants.SFSymbol.docFill
	}
}

#Preview {
	ContentView(document: .constant(DeconstructedDocument()))
}
