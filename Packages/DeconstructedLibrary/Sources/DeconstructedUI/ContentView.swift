//
//  ContentView.swift
//  Deconstructed
//
//  Created by Cristian Díaz on 26.01.26.
//

import ComposableArchitecture
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
