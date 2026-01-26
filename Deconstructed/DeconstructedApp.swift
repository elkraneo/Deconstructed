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
				.ignoresSafeArea(.all, edges: .top)
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
		let packageURL = url

		do {
			// 1. Create the SPM package folder
			try FileManager.default.createDirectory(at: packageURL, withIntermediateDirectories: true)

			// 2. Generate Package.swift and Sources/
			try DeconstructedDocument.generateSPMPackage(at: packageURL, projectName: projectName)

			// 3. Create the .realitycomposerpro document inside
			let documentURL = packageURL.appendingPathComponent("Package.realitycomposerpro")

			// Use consolidated logic from DeconstructedDocument
			let wrapper = DeconstructedDocument.createInitialBundle(projectName: projectName)
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
}
