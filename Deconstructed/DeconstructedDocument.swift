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

	/// Creates the .realitycomposerpro bundle contents
	static func createInitialBundle(projectName: String = "MyProject") -> FileWrapper {
		let bundle = FileWrapper(directoryWithFileWrappers: [:])
		let encoder = JSONEncoder()
		encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

		let sceneUUID = UUID().uuidString
		// Standard RCP path structure within a Swift Package
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

		// 1. Use swift package init to create a clean SPM structure
		let process = Process()
		process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
		process.arguments = [
			"swift", "package", "init",
			"--type", "empty", // Cleaner than 'library', no cleanup needed
			"--name", projectName
		]
		process.currentDirectoryURL = packageURL

		try process.run()
		process.waitUntilExit()

		guard process.terminationStatus == 0 else {
			throw CocoaError(.fileWriteInvalidFileName)
		}

		// 2. Write our custom Package.swift with macOS 26 / visionOS 26
		let packageSwiftURL = packageURL.appendingPathComponent("Package.swift")
		try PackageTemplate.content(projectName: projectName)
			.write(to: packageSwiftURL, atomically: true, encoding: .utf8)

		// 3. Create Sources structure
		let sourcesURL = packageURL.appendingPathComponent("Sources").appendingPathComponent(projectName)
		try fileManager.createDirectory(at: sourcesURL, withIntermediateDirectories: true)

		// 4. Create bundle accessor Swift file
		let swiftFileURL = sourcesURL.appendingPathComponent("\(projectName).swift")
		try BundleAccessorTemplate.content(projectName: projectName)
			.write(to: swiftFileURL, atomically: true, encoding: .utf8)

		// 5. Create .rkassets bundle
		let rkassetsURL = sourcesURL.appendingPathComponent("\(projectName).rkassets")
		try fileManager.createDirectory(at: rkassetsURL, withIntermediateDirectories: true)

		// 6. Create Scene.usda (RealityKit scene format)
		let sceneURL = rkassetsURL.appendingPathComponent("Scene.usda")
		try SceneTemplate.emptyScene()
			.write(to: sceneURL, atomically: true, encoding: .utf8)
	}
}
