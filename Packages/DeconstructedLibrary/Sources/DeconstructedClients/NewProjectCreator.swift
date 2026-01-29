import AppKit
import DeconstructedCore
import Foundation
import ProjectScaffolding
import RCPPackage

@MainActor
public final class NewProjectCreator {
	public static let shared = NewProjectCreator()

	public func createNewProject() async {
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
			try ProjectScaffolder.createPackage(at: packageURL, projectName: projectName)

			// 3. Create the .realitycomposerpro document inside
			let documentURL = packageURL.appendingPathComponent(DeconstructedConstants.FileName.document)

			// Use consolidated logic from RCPPackage
			let wrapper = RCPPackage.createInitialBundle(projectName: projectName)
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
