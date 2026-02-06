import DeconstructedModels
import ComposableArchitecture
import Foundation

@DependencyClient
public struct ProjectDataIndexClient: Sendable {
	public var registerNewScene: @Sendable (_ documentURL: URL, _ sceneURL: URL) throws -> Void
	public var registerMove: @Sendable (_ documentURL: URL, _ from: URL, _ to: URL) throws -> Void
}

extension ProjectDataIndexClient: DependencyKey {
	public static var liveValue: Self {
		Self(
			registerNewScene: { documentURL, sceneURL in
				try updateProjectDataForNewScene(documentURL: documentURL, sceneURL: sceneURL)
			},
			registerMove: { documentURL, from, to in
				try updateProjectDataForMove(documentURL: documentURL, from: from, to: to)
			}
		)
	}
}

private func updateProjectDataForNewScene(documentURL: URL, sceneURL: URL) throws {
	let projectDataURL = documentURL
		.appendingPathComponent(DeconstructedConstants.DirectoryName.projectData)
		.appendingPathComponent(DeconstructedConstants.FileName.mainJson)
	let data = try Data(contentsOf: projectDataURL)
	var projectData = try JSONDecoder().decode(RCPProjectData.self, from: data)

	let sceneUUID = UUID().uuidString
	let scenePath = try scenePathForURL(documentURL: documentURL, sceneURL: sceneURL)
	projectData.pathsToIds[scenePath] = sceneUUID
	projectData.uuidToIntID[sceneUUID] = Int64.random(in: Int64.min...Int64.max)

	let encoder = JSONEncoder()
	encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
	let updated = try encoder.encode(projectData)
	try updated.write(to: projectDataURL, options: .atomic)

	try updateSceneMetadataListForNewScene(documentURL: documentURL, sceneUUID: sceneUUID)
	try ensurePluginDataForScene(documentURL: documentURL, sceneUUID: sceneUUID)
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
