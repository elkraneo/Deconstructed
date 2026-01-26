//
//  DeconstructedApp.swift
//  Deconstructed
//
//  Created by Cristian Díaz on 26.01.26.
//

import SwiftUI

@main
struct DeconstructedApp: App {
	@NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

	var body: some Scene {
		DocumentGroup(newDocument: DeconstructedDocument()) { file in
			ContentView(document: file.$document)
				.frame(minWidth: 800, minHeight: 600)
		}
		.commands {
			CommandGroup(replacing: .newItem) {
				Button("New Project...") {
					createNewProject()
				}
				.keyboardShortcut("n", modifiers: .command)
			}
		}

		Window("Welcome to Deconstructed", id: "welcome") {
			WelcomeWindowContent()
		}
		.windowStyle(.hiddenTitleBar)
		.windowResizability(.contentSize)
		.defaultPosition(.center)
		.commandsRemoved()
		.defaultLaunchBehavior(.presented)
	}

	private func createNewProject() {
		Task {
			await NewProjectCreator.shared.createNewProject()
		}
	}
}

final class AppDelegate: NSObject, NSApplicationDelegate {
	func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
		false
	}
}

/// Wrapper to handle document environment actions
struct WelcomeWindowContent: View {
	@Environment(\.dismissWindow) private var dismissWindow
	@Environment(\.openDocument) private var openDocument

	var body: some View {
		LaunchExperience(
			onNewProject: {
				dismissWindow(id: "welcome")
				Task {
					await NewProjectCreator.shared.createNewProject()
				}
			},
			onOpenProject: { url in
				dismissWindow(id: "welcome")
				Task {
					try? await openDocument(at: url)
				}
			}
		)
	}
}

// MARK: - New Project Creator

@MainActor
final class NewProjectCreator {
	static let shared = NewProjectCreator()

	func createNewProject() async {
		let savePanel = NSSavePanel()
		savePanel.title = "New Project"
		savePanel.message = "Choose a location for your new project"
		savePanel.nameFieldLabel = "Project Name:"
		savePanel.nameFieldStringValue = "MyProject"
		savePanel.canCreateDirectories = true
		savePanel.showsTagField = false

		guard savePanel.runModal() == .OK, let url = savePanel.url else {
			return
		}

		let projectName = url.lastPathComponent
		let packageURL = url  // This becomes the SPM package folder

		do {
			// 1. Create the SPM package folder
			try FileManager.default.createDirectory(at: packageURL, withIntermediateDirectories: true)

			// 2. Generate Package.swift and Sources/
			try DeconstructedDocument.generateSPMPackage(at: packageURL, projectName: projectName)

			// 3. Create the .realitycomposerpro document inside
			let documentURL = packageURL.appendingPathComponent("Package.realitycomposerpro")

			// Create document bundle with correct paths for this project
			let wrapper = createBundleWithPaths(projectName: projectName)
			try wrapper.write(to: documentURL, options: .atomic, originalContentsURL: nil)

			// 4. Open the created document
			NSDocumentController.shared.openDocument(withContentsOf: documentURL, display: true) { _, _, error in
				if let error {
					NSAlert(error: error).runModal()
				}
			}
		} catch {
			NSAlert(error: error).runModal()
		}
	}

	private func createBundleWithPaths(projectName: String) -> FileWrapper {
		let bundle = FileWrapper(directoryWithFileWrappers: [:])
		let encoder = JSONEncoder()
		encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

		let sceneUUID = UUID().uuidString
		let scenePath = "/\(projectName)/Sources/\(projectName)/\(projectName).rkassets/Scene.usda"

		// ProjectData/main.json
		let projectDataFolder = FileWrapper(directoryWithFileWrappers: [:])
		projectDataFolder.preferredFilename = "ProjectData"
		let projectData = RCPProjectData.initial(scenePath: scenePath, sceneUUID: sceneUUID)
		if let mainJson = try? encoder.encode(projectData) {
			projectDataFolder.addRegularFile(withContents: mainJson, preferredFilename: "main.json")
		}
		bundle.addFileWrapper(projectDataFolder)

		// WorkspaceData/
		let workspaceDataFolder = FileWrapper(directoryWithFileWrappers: [:])
		workspaceDataFolder.preferredFilename = "WorkspaceData"

		// Settings.rcprojectdata
		if let settingsJson = try? encoder.encode(RCPSettings.initial()) {
			workspaceDataFolder.addRegularFile(withContents: settingsJson, preferredFilename: "Settings.rcprojectdata")
		}

		// SceneMetadataList.json
		let sceneMetadataList = RCPSceneMetadataList.initial(sceneUUID: sceneUUID)
		if let metadataJson = try? sceneMetadataList.encode() {
			workspaceDataFolder.addRegularFile(withContents: metadataJson, preferredFilename: "SceneMetadataList.json")
		}
		bundle.addFileWrapper(workspaceDataFolder)

		// Library/
		let library = FileWrapper(directoryWithFileWrappers: [:])
		library.preferredFilename = "Library"
		bundle.addFileWrapper(library)

		// PluginData/
		let pluginData = FileWrapper(directoryWithFileWrappers: [:])
		pluginData.preferredFilename = "PluginData"
		bundle.addFileWrapper(pluginData)

		return bundle
	}
}
