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
public nonisolated struct RCPSceneMetadataList: Sendable, Codable {
	public var scenes: [String: SceneMetadata]

	public struct SceneMetadata: Sendable {
		public var uuid: String
		public var name: String
		public var isExpanded: Bool
		public var isLocked: Bool

		public init(
			uuid: String,
			name: String,
			isExpanded: Bool,
			isLocked: Bool
		) {
			self.uuid = uuid
			self.name = name
			self.isExpanded = isExpanded
			self.isLocked = isLocked
		}
	}

	public init(scenes: [String: SceneMetadata]) {
		self.scenes = scenes
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

	/// Coding keys for the root object
	private struct CodingKeys: CodingKey {
		var stringValue: String
		var intValue: Int? { nil }

		init?(stringValue: String) {
			self.stringValue = stringValue
		}

		init?(intValue: Int) {
			nil
		}
	}

	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		var scenes: [String: SceneMetadata] = [:]

		for key in container.allKeys {
			let sceneContainer = try container.nestedContainer(
				keyedBy: SceneCodingKeys.self,
				forKey: key
			)
			var metadataList = try sceneContainer.nestedUnkeyedContainer(
				forKey: .objectMetadataList
			)

			// First element: [uuid, name]
			var firstArray = try metadataList.nestedUnkeyedContainer()
			let uuid = try firstArray.decode(String.self)
			let name = try firstArray.decode(String.self)

			// Second element: {isExpanded, isLocked}
			let flags = try metadataList.decode(SceneFlags.self)

			scenes[key.stringValue] = SceneMetadata(
				uuid: uuid,
				name: name,
				isExpanded: flags.isExpanded,
				isLocked: flags.isLocked
			)
		}

		self.scenes = scenes
	}

	public func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)

		for (key, metadata) in scenes {
			let key = CodingKeys(stringValue: key)!
			var sceneContainer = container.nestedContainer(
				keyedBy: SceneCodingKeys.self,
				forKey: key
			)
			var metadataList = sceneContainer.nestedUnkeyedContainer(
				forKey: .objectMetadataList
			)

			// First element: [uuid, name]
			var firstArray = metadataList.nestedUnkeyedContainer()
			try firstArray.encode(metadata.uuid)
			try firstArray.encode(metadata.name)

			// Second element: {isExpanded, isLocked}
			try metadataList.encode(
				SceneFlags(
					isExpanded: metadata.isExpanded,
					isLocked: metadata.isLocked
				)
			)
		}
	}

	private enum SceneCodingKeys: String, CodingKey {
		case objectMetadataList
	}

	private struct SceneFlags: Codable, Sendable {
		let isExpanded: Bool
		let isLocked: Bool
	}

	/// Convenience method to encode with pretty printing and sorted keys
	public func encode() throws -> Data {
		let encoder = JSONEncoder()
		encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
		return try encoder.encode(self)
	}
}
