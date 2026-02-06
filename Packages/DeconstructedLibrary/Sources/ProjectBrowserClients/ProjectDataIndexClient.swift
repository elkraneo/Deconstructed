import DeconstructedModels
import ComposableArchitecture
import Foundation

@DependencyClient
public struct ProjectDataIndexClient: Sendable {
	public var registerNewScene: @Sendable (
		_ documentURL: URL,
		_ sceneURL: URL,
		_ sceneUUID: String
	) throws -> Void
	public var registerMove: @Sendable (_ documentURL: URL, _ from: URL, _ to: URL) throws -> Void
}

extension ProjectDataIndexClient: DependencyKey {
	public static var liveValue: Self {
		Self(
			registerNewScene: { documentURL, sceneURL, sceneUUID in
				try updateProjectDataForNewScene(
					documentURL: documentURL,
					sceneURL: sceneURL,
					sceneUUID: sceneUUID
				)
			},
			registerMove: { documentURL, from, to in
				try updateProjectDataForMove(documentURL: documentURL, from: from, to: to)
			}
		)
	}
}

private func updateProjectDataForNewScene(
	documentURL: URL,
	sceneURL: URL,
	sceneUUID: String
) throws {
	let projectDataURL = documentURL
		.appendingPathComponent(DeconstructedConstants.DirectoryName.projectData)
		.appendingPathComponent(DeconstructedConstants.FileName.mainJson)
	let data = try Data(contentsOf: projectDataURL)
	var projectData = try JSONDecoder().decode(RCPProjectData.self, from: data)

	let scenePath = try scenePathForURL(documentURL: documentURL, sceneURL: sceneURL)
	projectData.pathsToIds[scenePath] = sceneUUID
	projectData.uuidToIntID[sceneUUID] = numericSceneID(from: sceneUUID)

	let encoder = JSONEncoder()
	encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
	let updated = try encoder.encode(projectData)
	try updated.write(to: projectDataURL, options: .atomic)

	try updateSceneMetadataListForNewScene(documentURL: documentURL, sceneUUID: sceneUUID)
	try ensurePluginDataForScene(documentURL: documentURL, sceneUUID: sceneUUID)
}

private func numericSceneID(from sceneUUID: String) -> Int64 {
	guard let uuid = UUID(uuidString: sceneUUID) else {
		return 0
	}
	return Int64(bitPattern: UInt64(uuid.uuid.0) << 56
		| UInt64(uuid.uuid.1) << 48
		| UInt64(uuid.uuid.2) << 40
		| UInt64(uuid.uuid.3) << 32
		| UInt64(uuid.uuid.4) << 24
		| UInt64(uuid.uuid.5) << 16
		| UInt64(uuid.uuid.6) << 8
		| UInt64(uuid.uuid.7))
}

private func updateProjectDataForMove(documentURL: URL, from: URL, to: URL) throws {
	let projectDataURL = documentURL
		.appendingPathComponent(DeconstructedConstants.DirectoryName.projectData)
		.appendingPathComponent(DeconstructedConstants.FileName.mainJson)
	let data = try Data(contentsOf: projectDataURL)
	let decoder = JSONDecoder()
	var projectData = try decoder.decode(RCPProjectData.self, from: data)

	let rootURL = documentURL.deletingLastPathComponent()
	let fromComponents = relativeComponents(from: rootURL, to: from)
	let toComponents = relativeComponents(from: rootURL, to: to)
	guard !fromComponents.isEmpty, !toComponents.isEmpty else {
		return
	}

	var updatedPaths: [String: String] = [:]
	for (path, uuid) in projectData.pathsToIds {
		let components = pathComponents(from: path)
		if components.starts(with: fromComponents) {
			let newComponents = toComponents + components.dropFirst(fromComponents.count)
			let newPath = encodedScenePath(from: Array(newComponents))
			updatedPaths[newPath] = uuid
		} else {
			updatedPaths[path] = uuid
		}
	}

	projectData.pathsToIds = updatedPaths
	let encoder = JSONEncoder()
	encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
	let updated = try encoder.encode(projectData)
	try updated.write(to: projectDataURL, options: .atomic)
}

private func scenePathForURL(documentURL: URL, sceneURL: URL) throws -> String {
	let rootURL = documentURL.deletingLastPathComponent()
	let components = relativeComponents(from: rootURL, to: sceneURL)
	guard !components.isEmpty else {
		throw CocoaError(.fileReadInvalidFileName)
	}
	return encodedScenePath(from: components)
}

private func relativeComponents(from rootURL: URL, to fileURL: URL) -> [String] {
	let rootComponents = rootURL.standardizedFileURL.pathComponents
	let fileComponents = fileURL.standardizedFileURL.pathComponents
	guard fileComponents.starts(with: rootComponents) else {
		return []
	}
	return Array(fileComponents.dropFirst(rootComponents.count))
}

private func pathComponents(from path: String) -> [String] {
	path.split(separator: "/")
		.map { String($0) }
		.map { $0.removingPercentEncoding ?? $0 }
}

private func encodedScenePath(from components: [String]) -> String {
	let encoded = components.map { component in
		component.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? component
	}
	return "/" + encoded.joined(separator: "/")
}

private func updateSceneMetadataListForNewScene(documentURL: URL, sceneUUID: String) throws {
	let metadataURL = documentURL
		.appendingPathComponent(DeconstructedConstants.DirectoryName.workspaceData)
		.appendingPathComponent(DeconstructedConstants.FileName.sceneMetadataList)
	let existingData = try? Data(contentsOf: metadataURL)
	var metadataList: RCPSceneMetadataList
	if let existingData,
	   let decoded = try? JSONDecoder().decode(RCPSceneMetadataList.self, from: existingData) {
		metadataList = decoded
	} else {
		metadataList = RCPSceneMetadataList(scenes: [:])
	}

	if metadataList.scenes[sceneUUID] == nil {
		metadataList.scenes[sceneUUID] = RCPSceneMetadataList.SceneMetadata(
			uuid: sceneUUID,
			name: DeconstructedConstants.DefaultValue.rootNodeName,
			isExpanded: true,
			isLocked: false
		)
	}

	let updated = try metadataList.encode()
	try updated.write(to: metadataURL, options: .atomic)
}

private func ensurePluginDataForScene(documentURL: URL, sceneUUID: String) throws {
	let pluginRoot = documentURL
		.appendingPathComponent(DeconstructedConstants.DirectoryName.pluginData)
		.appendingPathComponent(sceneUUID)
		.appendingPathComponent(DeconstructedConstants.FileName.shaderGraphEditorPluginID)
	let fileURL = pluginRoot.appendingPathComponent(DeconstructedConstants.FileName.shaderGraphEditorPluginID)

	if FileManager.default.fileExists(atPath: fileURL.path) {
		return
	}

	try FileManager.default.createDirectory(at: pluginRoot, withIntermediateDirectories: true)
	let payload: [String: Any] = [
		DeconstructedConstants.JSONKey.materialPreviewEnvironmentType: DeconstructedConstants.DefaultValue.materialPreviewEnvironmentType,
		DeconstructedConstants.JSONKey.materialPreviewObjectType: DeconstructedConstants.DefaultValue.materialPreviewObjectType
	]
	let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
	try data.write(to: fileURL, options: .atomic)
}
