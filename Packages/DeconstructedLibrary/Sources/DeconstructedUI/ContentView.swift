//
//  ContentView.swift
//  Deconstructed
//
//  Created by Cristian Díaz on 26.01.26.
//

import ComposableArchitecture
import DeconstructedModels
import Foundation
import ProjectBrowserFeature
import ProjectBrowserUI
import RCPDocument
import SwiftUI

public struct ContentView: View {
	@Binding public var document: DeconstructedDocument
	@State private var store: StoreOf<ProjectBrowserFeature>?

	// Tab selection
	@State private var selectedTab: EditorTab = .projectBrowser

	enum EditorTab: String, CaseIterable, Identifiable {
		case projectBrowser = "Project Browser"
		case shaderGraph = "Shader Graph"
		case timeline = "Timelines"
		case audio = "Audio Mixer"
		case statistics = "Statistics"
		case debug = "Debug Info"  // The old view

		var id: String { rawValue }
		var icon: String {
			switch self {
			case .projectBrowser: return "square.grid.2x2"
			case .shaderGraph: return "circle.hexagongrid"
			case .timeline: return "clock"
			case .audio: return "waveform"
			case .statistics: return "chart.bar"
			case .debug: return "ladybug"
			}
		}
	}

	public init(document: Binding<DeconstructedDocument>) {
		self._document = document
	}

	public var body: some View {
		VStack(spacing: 0) {
			Spacer()
				.frame(height: 200)
			// Editor Toolbar / Tab Bar
			Picker("Editor Mode", selection: $selectedTab) {
				ForEach(EditorTab.allCases) { tab in
					Label(tab.rawValue, systemImage: tab.icon)
						.tag(tab)
				}
			}
			.pickerStyle(.segmented)
			.padding()

			Divider()

			// Main Content
			switch selectedTab {
			case .projectBrowser:
				if let store {
					ProjectBrowserView(store: store)
				} else {
					ContentUnavailableView(
						"Loading...",
						systemImage: "arrow.triangle.2.circlepath"
					)
				}

			case .debug:
				// Existing debug view
				DebugFileStructureView(document: document)

			default:
				ContentUnavailableView(
					selectedTab.rawValue,
					systemImage: selectedTab.icon,
					description: Text("This editor is not yet implemented.")
				)
			}
		}
		.onAppear {
			if store == nil {
				store = Store(initialState: ProjectBrowserFeature.State()) {
					ProjectBrowserFeature()
				}
			}
		}
		// When document URL becomes available (from DocumentGroup), load assets
		.onChange(of: document.documentURL) { oldUrl, newUrl in
			if let newUrl, let store {
				store.send(.loadAssets(documentURL: newUrl))
			}
		}
		// Also Trigger immediately if we already have it (unlikely on first render but good safety)
		.task {
			if let url = document.documentURL, let store {
				store.send(.loadAssets(documentURL: url))
			}
		}
	}
}

// Extracted the old view to keep ContentView clean
struct DebugFileStructureView: View {
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
