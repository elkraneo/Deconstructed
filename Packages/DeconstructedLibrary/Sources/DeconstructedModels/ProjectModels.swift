import Foundation

/// Represents the `ProjectData/main.json` file
public nonisolated struct RCPProjectData: Codable, Sendable {
	public var pathsToIds: [String: String]
	public var projectID: Int64
	public var uuidToIntID: [String: Int64]

	public static func initial(scenePath: String, sceneUUID: String) -> RCPProjectData {
		return RCPProjectData(
			pathsToIds: [scenePath: sceneUUID],
			projectID: Int64.random(in: Int64.min...Int64.max),
			uuidToIntID: [sceneUUID: Int64.random(in: Int64.min...Int64.max)]
		)
	}

	/// Normalized scene paths (deduplicated using URL path comparison)
	public var normalizedScenePaths: [String: String] {
		var result: [String: String] = [:]
		for (path, uuid) in pathsToIds {
			// Parse as URL and extract pathComponents for proper comparison
			let url = URL(fileURLWithPath: path)
			// Filter out empty/leading-slash components
			let components = url.pathComponents.filter { $0 != "" && $0 != "/" }
			// Reconstruct using URL by appending each component
			var normalized = URL(fileURLWithPath: "")
			for component in components {
				normalized.appendPathComponent(component)
			}
			// Use the standardized path string as key
			result[normalized.path] = uuid
		}
		return result
	}

	/// Number of unique scenes (accounting for path format differences)
	public var uniqueSceneCount: Int {
		normalizedScenePaths.count
	}
}

/// Represents the `WorkspaceData/Settings.rcprojectdata` file
public nonisolated struct RCPSettings: Codable, Sendable {
	public var cameraPresets: [String: CameraPreset]?
	public var secondaryToolbarData: ToolbarData
	public var unitDefaults: [String: String]?

	public struct CameraPreset: Codable, Sendable {}

	public struct ToolbarData: Codable, Sendable {
		public var isGridVisible: Bool
	}

	public static func initial() -> RCPSettings {
		return RCPSettings(
			cameraPresets: [:],
			secondaryToolbarData: ToolbarData(isGridVisible: true),
			unitDefaults: [
				"kg": "g",
				"kg⋅m²": "kg⋅m²",
				"m": "cm",
				"m/s": "m/s",
				"m/s²": "m/s²",
				"s": "s",
				"°": "°"
			]
		)
	}
}

/// Represents `WorkspaceData/SceneMetadataList.json`
/// Structure: { "uuid": { "objectMetadataList": [[uuid, name], {isExpanded, isLocked}] } }
public nonisolated struct RCPSceneMetadataList: Sendable {
	public var scenes: [String: SceneMetadata]

	public struct SceneMetadata: Sendable {
		public var uuid: String
		public var name: String
		public var isExpanded: Bool
		public var isLocked: Bool
	}

	public static func initial(sceneUUID: String, sceneName: String = "Root") -> RCPSceneMetadataList {
		return RCPSceneMetadataList(scenes: [
			sceneUUID: SceneMetadata(
				uuid: sceneUUID,
				name: sceneName,
				isExpanded: true,
				isLocked: false
			)
		])
	}

	/// Custom JSON encoding to match RCP's format
	public func encode() throws -> Data {
		var root: [String: Any] = [:]

		for (key, metadata) in scenes {
			let objectMetadataList: [Any] = [
				[metadata.uuid, metadata.name],
				["isExpanded": metadata.isExpanded, "isLocked": metadata.isLocked]
			]
			root[key] = ["objectMetadataList": objectMetadataList]
		}

		return try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
	}
}
