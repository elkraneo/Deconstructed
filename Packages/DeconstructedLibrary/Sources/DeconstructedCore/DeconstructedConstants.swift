import Foundation

/// Centralized constants for Reality Composer Pro file formats, paths, and naming conventions.
///
/// This file contains all string literals related to:
/// - File extensions (`.rkassets`, `.usda`, etc.)
/// - Directory names (`Sources`, `ProjectData`, etc.)
/// - File names (`main.json`, `Scene.usda`, etc.)
/// - Path patterns and URL construction helpers
/// - SFSymbol names used throughout the app
///
/// Using these constants prevents typos and makes it easier to update naming conventions.
public enum DeconstructedConstants {

	// MARK: - File Extensions

	public enum FileExtension {
		/// RealityKit assets bundle extension
		public static let rkassets = "rkassets"

		/// Reality Composer Pro package extension
		public static let realityComposerPro = "realitycomposerpro"

		/// USD ASCII format
		public static let usda = "usda"

		/// USD binary format
		public static let usdc = "usdc"

		/// USD zip format
		public static let usdz = "usdz"

		/// Generic USD extension
		public static let usd = "usd"

		/// JSON data format
		public static let json = "json"

		/// Swift source code
		public static let swift = "swift"

		/// Image formats
		public static let png = "png"
		public static let jpg = "jpg"
		public static let jpeg = "jpeg"
		public static let exr = "exr"
		public static let hdr = "hdr"

		/// Audio formats
		public static let wav = "wav"
		public static let mp3 = "mp3"
		public static let aiff = "aiff"

		/// RealityKit reality file
		public static let reality = "reality"

		/// Reality Composer Pro project data extension
		public static let rcprojectdata = "rcprojectdata"

		/// Reality Composer Pro user data extension
		public static let rcuserdata = "rcuserdata"

		/// All image extensions that can be imported as textures
		public static let allImageExtensions: [String] = [png, jpg, jpeg, exr, hdr]

		/// All audio extensions
		public static let allAudioExtensions: [String] = [wav, mp3, aiff]

		/// All USD extensions
		public static let allUSDExtensions: [String] = [usda, usdc, usdz, usd]
	}

	// MARK: - Directory Names

	public enum DirectoryName {
		/// Swift package Sources directory
		public static let sources = "Sources"

		/// Project metadata directory inside .realitycomposerpro
		public static let projectData = "ProjectData"

		/// Workspace settings directory inside .realitycomposerpro
		public static let workspaceData = "WorkspaceData"

		/// Library directory inside .realitycomposerpro
		public static let library = "Library"

		/// Plugin data directory inside .realitycomposerpro
		public static let pluginData = "PluginData"

		/// All top-level directories in a .realitycomposerpro package
		public static let allPackageDirectories: [String] = [
			projectData, workspaceData, library, pluginData
		]
	}

	// MARK: - File Names

	public enum FileName {
		/// Main project metadata file
		public static let mainJson = "main.json"

		/// Default scene file name
		public static let sceneUsda = "Scene.usda"

		/// Workspace settings file
		public static let settings = "Settings.rcprojectdata"

		/// Scene metadata index file
		public static let sceneMetadataList = "SceneMetadataList.json"

		/// Default name for new folders
		public static let newFolder = "New Folder"

		/// Default name for new scenes
		public static let untitledScene = "Untitled Scene"

		/// Package.swift manifest file
		public static let packageManifest = "Package.swift"

		/// Default document name
		public static let document = "Package.realitycomposerpro"

		/// Shader graph editor plugin identifier file
		public static let shaderGraphEditorPluginID = "ShaderGraphEditorPluginID"
	}

	// MARK: - Path Patterns

	public enum PathPattern {
		/// Template for rkassets path: "Sources/{projectName}/{projectName}.rkassets"
		public static func rkassets(projectName: String) -> String {
			"\(DirectoryName.sources)/\(projectName)/\(projectName).\(FileExtension.rkassets)"
		}

		/// Template for scene path in main.json: "/{projectName}/Sources/{projectName}/{projectName}.rkassets/{sceneName}.usda"
		public static func scenePath(projectName: String, sceneName: String = "Scene") -> String {
			"/\(projectName)/\(DirectoryName.sources)/\(projectName)/\(projectName).\(FileExtension.rkassets)/\(sceneName).\(FileExtension.usda)"
		}

		/// Template for user data file name: "{username}.rcuserdata"
		public static func userDataFile(username: String) -> String {
			"\(username).\(FileExtension.rcuserdata)"
		}

		/// Template for project-specific rkassets bundle name: "{projectName}.rkassets"
		public static func rkassetsBundle(projectName: String) -> String {
			"\(projectName).\(FileExtension.rkassets)"
		}
	}

	// MARK: - UTType Identifiers

	public enum UTTypeIdentifier {
		/// Reality Composer Pro document type identifier
		public static let realityComposerPro = "com.apple.realitycomposerpro"
	}

	// MARK: - SFSymbol Names

	public enum SFSymbol {
		// MARK: File Type Icons

		/// Generic document
		public static let doc = "doc"
		public static let docFill = "doc.fill"
		public static let docText = "doc.text"
		public static let docTextFill = "doc.text.fill"

		/// Document with question mark (error/unknown)
		public static let docQuestionmark = "doc.questionmark"

		/// Folder icons
		public static let folder = "folder"
		public static let folderFill = "folder.fill"

		/// RealityKit/3D related
		public static let cubeTransparent = "cube.transparent"
		public static let cubeTransparentFill = "cube.transparent.fill"
		public static let cubeFill = "cube.fill"

		/// Package/bundle
		public static let shippingboxFill = "shippingbox.fill"

		/// Media types
		public static let photoFill = "photo.fill"
		public static let waveform = "waveform"
		public static let arkit = "arkit"
		public static let swift = "swift"

		// MARK: UI Icons

		/// Grid view
		public static let squareGrid2x2 = "square.grid.2x2"

		/// Debug/ladybug
		public static let ladybug = "ladybug"

		/// Loading
		public static let arrowTriangle2Circlepath = "arrow.triangle.2.circlepath"

		/// Close
		public static let xmark = "xmark"

		/// Navigation
		public static let chevronRight = "chevron.right"
		public static let chevronDown = "chevron.down"

		/// Actions
		public static let plus = "plus"
		public static let plusCircleFill = "plus.circle.fill"
		public static let minus = "minus"
		public static let pencil = "pencil"
		public static let trash = "trash"
		public static let squareAndArrowDown = "square.and.arrow.down"
		public static let docOnDoc = "doc.on.doc"
		public static let squareAndArrowUp = "square.and.arrow.up"
		public static let exclamationmarkTriangle = "exclamationmark.triangle"

		/// View options
		public static let listBullet = "list.bullet"
		public static let listBulletRectanglePortrait = "list.bullet.rectangle.portrait"
		public static let arrowUpArrowDown = "arrow.up.arrow.down"
		public static let magnifyingglass = "magnifyingglass"
		public static let line3HorizontalDecreaseCircle = "line.3.horizontal.decrease.circle"

		/// Timeline
		public static let clock = "clock"

		/// Statistics
		public static let chartBar = "chart.bar"

		/// Shader graph
		public static let circleHexagongrid = "circle.hexagongrid"
	}

	// MARK: - JSON Keys

	/// Keys used in Reality Composer Pro JSON files
	public enum JSONKey {
		// ProjectData/main.json
		public static let pathsToIds = "pathsToIds"
		public static let uuidToIntID = "uuidToIntID"
		public static let projectID = "projectID"

		// WorkspaceData/SceneMetadataList.json
		public static let objectMetadataList = "objectMetadataList"
		public static let isExpanded = "isExpanded"
		public static let isLocked = "isLocked"

		// rcuserdata
		public static let openSceneRelativePaths = "openSceneRelativePaths"
		public static let selectedSceneRelativePath = "selectedSceneRelativePath"
		public static let sceneCameraHistory = "sceneCameraHistory"
		public static let date = "date"
		public static let title = "title"
		public static let transform = "transform"

		// Plugin data
		public static let materialPreviewEnvironmentType = "materialPreviewEnvironmentType"
		public static let materialPreviewObjectType = "materialPreviewObjectType"
	}

	// MARK: - Default Values

	public enum DefaultValue {
		/// Default project name for new projects
		public static let projectName = "MyProject"

		/// Default root node name in scene metadata
		public static let rootNodeName = "Root"

		/// Default material preview environment type
		public static let materialPreviewEnvironmentType = 2

		/// Default material preview object type
		public static let materialPreviewObjectType = 0
	}
}

// MARK: - URL Extension Helpers

public extension URL {
	/// Checks if the URL has the specified file extension
	func hasExtension(_ ext: String) -> Bool {
		pathExtension.lowercased() == ext.lowercased()
	}

	/// Returns true if this URL points to an .rkassets bundle
	var isRKAssets: Bool {
		hasExtension(DeconstructedConstants.FileExtension.rkassets)
	}

	/// Returns true if this URL points to a .realitycomposerpro package
	var isRealityComposerProPackage: Bool {
		hasExtension(DeconstructedConstants.FileExtension.realityComposerPro)
	}

	/// Returns true if this URL points to a USD file (usda, usdc, usdz, usd)
	var isUSDFile: Bool {
		DeconstructedConstants.FileExtension.allUSDExtensions.contains(pathExtension.lowercased())
	}

	/// Returns true if this URL points to an image texture file
	var isTextureFile: Bool {
		DeconstructedConstants.FileExtension.allImageExtensions.contains(pathExtension.lowercased())
	}

	/// Returns true if this URL points to an audio file
	var isAudioFile: Bool {
		DeconstructedConstants.FileExtension.allAudioExtensions.contains(pathExtension.lowercased())
	}
}
