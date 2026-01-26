import SwiftUI
import UniformTypeIdentifiers

extension UTType {
	/// The .realitycomposerpro bundle (the actual document)
	static let realityComposerPro = UTType(importedAs: "com.apple.realitycomposerpro")
}

struct DeconstructedDocument: FileDocument {
	/// The .realitycomposerpro bundle contents
	var bundle: FileWrapper

	/// URL of the document (set after opening, used to resolve sibling paths)
	var documentURL: URL?

	init(bundle: FileWrapper = createInitialBundle()) {
		self.bundle = bundle
	}

	static let readableContentTypes: [UTType] = [.realityComposerPro]

	init(configuration: ReadConfiguration) throws {
		guard configuration.file.isDirectory else {
			throw CocoaError(.fileReadCorruptFile)
		}
		bundle = configuration.file
	}

	func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
		return bundle
	}

	// MARK: - Parsed Data

	/// Parses ProjectData/main.json
	var parsedProjectData: RCPProjectData? {
		guard let projectDataFolder = bundle.fileWrappers?["ProjectData"],
		      let mainJsonWrapper = projectDataFolder.fileWrappers?["main.json"],
		      let data = mainJsonWrapper.regularFileContents
		else {
			return nil
		}
		return try? JSONDecoder().decode(RCPProjectData.self, from: data)
	}

	/// Parses WorkspaceData/Settings.rcprojectdata
	var parsedSettings: RCPSettings? {
		guard let workspaceFolder = bundle.fileWrappers?["WorkspaceData"],
		      let settingsWrapper = workspaceFolder.fileWrappers?["Settings.rcprojectdata"],
		      let data = settingsWrapper.regularFileContents
		else {
			return nil
		}
		return try? JSONDecoder().decode(RCPSettings.self, from: data)
	}

	// MARK: - Initial Bundle Creation

	/// Creates just the .realitycomposerpro bundle contents
	static func createInitialBundle() -> FileWrapper {
		let bundle = FileWrapper(directoryWithFileWrappers: [:])
		let encoder = JSONEncoder()
		encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

		// ProjectData/main.json
		let projectData = FileWrapper(directoryWithFileWrappers: [:])
		projectData.preferredFilename = "ProjectData"
		if let mainJson = try? encoder.encode(RCPProjectData.initial()) {
			projectData.addRegularFile(withContents: mainJson, preferredFilename: "main.json")
		}
		bundle.addFileWrapper(projectData)

		// WorkspaceData/
		let workspaceData = FileWrapper(directoryWithFileWrappers: [:])
		workspaceData.preferredFilename = "WorkspaceData"
		if let settingsJson = try? encoder.encode(RCPSettings.initial()) {
			workspaceData.addRegularFile(withContents: settingsJson, preferredFilename: "Settings.rcprojectdata")
		}
		bundle.addFileWrapper(workspaceData)

		// Library/ (empty)
		let library = FileWrapper(directoryWithFileWrappers: [:])
		library.preferredFilename = "Library"
		bundle.addFileWrapper(library)

		// PluginData/ (empty)
		let pluginData = FileWrapper(directoryWithFileWrappers: [:])
		pluginData.preferredFilename = "PluginData"
		bundle.addFileWrapper(pluginData)

		return bundle
	}
}

// MARK: - SPM Package Generation

extension DeconstructedDocument {
	/// Generates the surrounding SPM package at a given location
	/// Called after saving the .realitycomposerpro document to create Package.swift and Sources/
	static func generateSPMPackage(at packageURL: URL, projectName: String) throws {
		let fileManager = FileManager.default

		// 1. Use swift package init to create base structure
		let process = Process()
		process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
		process.arguments = [
			"swift", "package", "init",
			"--type", "library",
			"--name", projectName
		]
		process.currentDirectoryURL = packageURL

		try process.run()
		process.waitUntilExit()

		guard process.terminationStatus == 0 else {
			throw CocoaError(.fileWriteInvalidFileName)
		}

		// 2. Replace Package.swift with macOS 26 + RealityKit platform
		let packageSwiftURL = packageURL.appendingPathComponent("Package.swift")
		try PackageTemplate.content(projectName: projectName)
			.write(to: packageSwiftURL, atomically: true, encoding: .utf8)

		// 3. Replace the generated Swift file with our bundle accessor
		let sourcesURL = packageURL.appendingPathComponent("Sources").appendingPathComponent(projectName)
		let swiftFileURL = sourcesURL.appendingPathComponent("\(projectName).swift")
		try BundleAccessorTemplate.content(projectName: projectName)
			.write(to: swiftFileURL, atomically: true, encoding: .utf8)

		// 4. Create .rkassets bundle (not supported by swift package init)
		let rkassetsURL = sourcesURL.appendingPathComponent("\(projectName).rkassets")
		try fileManager.createDirectory(at: rkassetsURL, withIntermediateDirectories: true)

		// 5. Create Scene.usda (RealityKit scene format)
		let sceneURL = rkassetsURL.appendingPathComponent("Scene.usda")
		try SceneTemplate.emptyScene()
			.write(to: sceneURL, atomically: true, encoding: .utf8)
	}
}
