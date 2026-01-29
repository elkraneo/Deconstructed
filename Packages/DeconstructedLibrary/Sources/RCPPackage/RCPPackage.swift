import DeconstructedCore
import DeconstructedModels
import Foundation

public struct RCPPackage {
	public var bundle: FileWrapper

	public init(bundle: FileWrapper) {
		self.bundle = bundle
	}

	/// Parses ProjectData/main.json
	public var projectData: RCPProjectData? {
		guard let projectDataFolder = bundle.fileWrappers?[DeconstructedConstants.DirectoryName.projectData],
		      let mainJsonWrapper = projectDataFolder.fileWrappers?[DeconstructedConstants.FileName.mainJson],
		      let data = mainJsonWrapper.regularFileContents
		else {
			return nil
		}
		return try? JSONDecoder().decode(RCPProjectData.self, from: data)
	}

	/// Parses WorkspaceData/Settings.rcprojectdata
	public var settings: RCPSettings? {
		guard let workspaceFolder = bundle.fileWrappers?[DeconstructedConstants.DirectoryName.workspaceData],
		      let settingsWrapper = workspaceFolder.fileWrappers?[DeconstructedConstants.FileName.settings],
		      let data = settingsWrapper.regularFileContents
		else {
			return nil
		}
		return try? JSONDecoder().decode(RCPSettings.self, from: data)
	}

	/// Extracts project name from main.json paths
	/// Parses first path from pathsToIds dictionary (e.g., "/Base/Sources/Base/Base.rkassets/Scene.usda" -> "Base")
	public var projectName: String? {
		guard let projectData = projectData,
		      let firstPath = projectData.normalizedScenePaths.keys.first
		else {
			return nil
		}

		// Parse path like "/Base/Sources/Base/Base.rkassets/Scene.usda"
		// First component is project name
		let components = firstPath
			.split(separator: "/")
			.map { String($0) }
			.map { $0.removingPercentEncoding ?? $0 }
		guard components.count >= 4 else {
			return nil
		}

		// Return first component which is the project name
		return components[0]
	}

	/// Returns relative path from package root to the .rkassets directory
	/// Format: "Sources/{ProjectName}/{ProjectName}.rkassets"
	public var rkassetsRelativePath: String? {
		guard let name = projectName else {
			return nil
		}
		return DeconstructedConstants.PathPattern.rkassets(projectName: name)
	}

	/// Given document URL pointing to .realitycomposerpro bundle, returns the full URL to the .rkassets directory
	/// - Parameter documentURL: URL to the .realitycomposerpro bundle
	/// - Returns: URL to the .rkassets directory, or nil if resolution fails
	public func rkassetsURL(for documentURL: URL) -> URL? {
		guard let rkassetsPath = rkassetsRelativePath else {
			return nil
		}

		// Go up one level from .realitycomposerpro bundle to parent directory
		let parentURL = documentURL.deletingLastPathComponent()

		// Append the rkassets relative path
		return parentURL.appendingPathComponent(rkassetsPath)
	}

	/// Creates the .realitycomposerpro bundle contents
	public static func createInitialBundle(
		projectName: String = DeconstructedConstants.DefaultValue.projectName
	) -> FileWrapper {
		let bundle = FileWrapper(directoryWithFileWrappers: [:])
		let encoder = JSONEncoder()
		encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

		let sceneUUID = UUID().uuidString
		// Standard RCP path structure within a Swift Package
		let scenePath = DeconstructedConstants.PathPattern.scenePath(projectName: projectName)

		// ProjectData/main.json
		let projectDataFolder = FileWrapper(directoryWithFileWrappers: [:])
		projectDataFolder.preferredFilename = DeconstructedConstants.DirectoryName.projectData
		let projectData = RCPProjectData.initial(scenePath: scenePath, sceneUUID: sceneUUID)
		if let mainJson = try? encoder.encode(projectData) {
			projectDataFolder.addRegularFile(
				withContents: mainJson,
				preferredFilename: DeconstructedConstants.FileName.mainJson
			)
		}
		bundle.addFileWrapper(projectDataFolder)

		// WorkspaceData/
		let workspaceDataFolder = FileWrapper(directoryWithFileWrappers: [:])
		workspaceDataFolder.preferredFilename = DeconstructedConstants.DirectoryName.workspaceData

		// Settings.rcprojectdata
		if let settingsJson = try? encoder.encode(RCPSettings.initial()) {
			workspaceDataFolder.addRegularFile(
				withContents: settingsJson,
				preferredFilename: DeconstructedConstants.FileName.settings
			)
		}

		// SceneMetadataList.json
		let sceneMetadataList = RCPSceneMetadataList.initial(sceneUUID: sceneUUID)
		if let metadataJson = try? sceneMetadataList.encode() {
			workspaceDataFolder.addRegularFile(
				withContents: metadataJson,
				preferredFilename: DeconstructedConstants.FileName.sceneMetadataList
			)
		}
		bundle.addFileWrapper(workspaceDataFolder)

		// Library/ (empty)
		let library = FileWrapper(directoryWithFileWrappers: [:])
		library.preferredFilename = DeconstructedConstants.DirectoryName.library
		bundle.addFileWrapper(library)

		// PluginData/ (empty)
		let pluginData = FileWrapper(directoryWithFileWrappers: [:])
		pluginData.preferredFilename = DeconstructedConstants.DirectoryName.pluginData
		bundle.addFileWrapper(pluginData)

		return bundle
	}
}
