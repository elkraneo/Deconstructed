import ComposableArchitecture
import DeconstructedModels
import Foundation

@DependencyClient
public struct WorkspacePersistenceClient: Sendable {
	public var saveOpenScenes: @Sendable (_ documentURL: URL, _ openSceneURLs: [URL], _ selectedSceneURL: URL?) throws -> Void
	public var loadWorkspaceRestore: @Sendable (_ documentURL: URL) -> WorkspaceRestore?
	public var appendCameraHistory: @Sendable (_ documentURL: URL, _ sceneURL: URL, _ title: String, _ transform: [Float], _ date: Date) throws -> Void
	public var loadCameraHistory: @Sendable (_ documentURL: URL, _ sceneURL: URL) -> [CameraHistoryItem]
	public var loadGridVisibility: @Sendable (_ documentURL: URL) -> Bool?
	public var saveGridVisibility: @Sendable (_ documentURL: URL, _ isVisible: Bool) throws -> Void
}

extension WorkspacePersistenceClient: DependencyKey {
	public static var liveValue: Self {
		Self(
			saveOpenScenes: { documentURL, openSceneURLs, selectedSceneURL in
				try updateUserData(
					documentURL: documentURL,
					openSceneURLs: openSceneURLs,
					selectedSceneURL: selectedSceneURL
				)
			},
			loadWorkspaceRestore: { documentURL in
				loadWorkspaceRestore(documentURL: documentURL)
			},
			appendCameraHistory: { documentURL, sceneURL, title, transform, date in
				try updateSceneCameraHistory(
					documentURL: documentURL,
					sceneURL: sceneURL,
					title: title,
					transform: transform,
					date: date
				)
			},
			loadCameraHistory: { documentURL, sceneURL in
				loadCameraHistory(documentURL: documentURL, sceneURL: sceneURL)
			},
			loadGridVisibility: { documentURL in
				loadSettingsGridVisible(documentURL: documentURL)
			},
			saveGridVisibility: { documentURL, isVisible in
				try updateSettingsGridVisible(documentURL: documentURL, isVisible: isVisible)
			}
		)
	}
}

public extension DependencyValues {
	var workspacePersistenceClient: WorkspacePersistenceClient {
		get { self[WorkspacePersistenceClient.self] }
		set { self[WorkspacePersistenceClient.self] = newValue }
	}
}

private func loadCameraHistory(documentURL: URL, sceneURL: URL) -> [CameraHistoryItem] {
	guard let sceneUUID = sceneUUIDForURL(documentURL: documentURL, sceneURL: sceneURL) else {
		return []
	}
	let workspaceURL = documentURL.appendingPathComponent("WorkspaceData")
	guard let userDataURL = findUserDataURL(in: workspaceURL),
	      let rootObject = loadJSONDictionary(url: userDataURL),
	      let historyByScene = rootObject["sceneCameraHistory"] as? [String: Any] else {
		return []
	}

	let entries: [[String: Any]] = (historyByScene[sceneUUID] as? [[String: Any]]) ?? []
	let items: [CameraHistoryItem] = entries.compactMap { entry in
		guard let dateValue = entry["date"] as? TimeInterval,
		      let title = entry["title"] as? String,
		      let transformArray = entry["transform"] as? [NSNumber],
		      transformArray.count == 16 else {
			return nil
		}
		let date = Date(timeIntervalSinceReferenceDate: dateValue)
		let transform = transformArray.map { $0.floatValue }
		return CameraHistoryItem(date: date, title: title, transform: transform)
	}
	.sorted { $0.date < $1.date }
	if items.count <= cameraHistoryMaxEntries {
		return items
	}
	return Array(items.suffix(cameraHistoryMaxEntries))
}

private func updateUserData(
	documentURL: URL,
	openSceneURLs: [URL],
	selectedSceneURL: URL?
) throws {
	let workspaceURL = documentURL.appendingPathComponent(DeconstructedConstants.DirectoryName.workspaceData)
	let userDataURL = resolveUserDataURL(in: workspaceURL)
	let rkassetsURL = findRKAssets(for: documentURL)

	let openPaths = openSceneURLs.map { url in
		relativeScenePath(url, rkassetsURL: rkassetsURL)
	}
	let selectedPath = selectedSceneURL.map { url in
		relativeScenePath(url, rkassetsURL: rkassetsURL)
	}

	var rootObject = loadJSONDictionary(url: userDataURL) ?? [:]
	rootObject[RCUserDataKeys.openSceneRelativePaths] = openPaths
	if let selectedPath {
		rootObject[RCUserDataKeys.selectedSceneRelativePath] = selectedPath
	} else {
		rootObject.removeValue(forKey: RCUserDataKeys.selectedSceneRelativePath)
	}

	try writeJSONDictionary(rootObject, to: userDataURL)
}

private func loadWorkspaceRestore(documentURL: URL) -> WorkspaceRestore? {
	let workspaceURL = documentURL.appendingPathComponent("WorkspaceData")
	guard let userDataURL = findUserDataURL(in: workspaceURL),
	      let rootObject = loadJSONDictionary(url: userDataURL) else {
		return nil
	}
	let rkassetsURL = findRKAssets(for: documentURL)
	let openPaths = rootObject["openSceneRelativePaths"] as? [String] ?? []
	let openSceneURLs = openPaths.compactMap { path in
		sceneURL(fromRelativePath: path, rkassetsURL: rkassetsURL)
	}.filter { FileManager.default.fileExists(atPath: $0.path) }

	let selectedPath = rootObject["selectedSceneRelativePath"] as? String
	let selectedSceneURL = selectedPath.flatMap { path in
		sceneURL(fromRelativePath: path, rkassetsURL: rkassetsURL)
	}

	let historyByScene = rootObject["sceneCameraHistory"] as? [String: Any] ?? [:]
	var cameraTransforms: [URL: [Float]] = [:]
	for url in openSceneURLs {
		if let uuid = sceneUUIDForURL(documentURL: documentURL, sceneURL: url),
		   let entries = historyByScene[uuid] as? [[String: Any]],
		   let last = entries.last,
		   let transformArray = last["transform"] as? [NSNumber],
		   transformArray.count == 16 {
			cameraTransforms[url] = transformArray.map { $0.floatValue }
		}
	}

	return WorkspaceRestore(
		openSceneURLs: openSceneURLs,
		selectedSceneURL: selectedSceneURL,
		cameraTransforms: cameraTransforms
	)
}

private func updateSceneCameraHistory(
	documentURL: URL,
	sceneURL: URL,
	title: String,
	transform: [Float],
	date: Date
) throws {
	guard let sceneUUID = sceneUUIDForURL(documentURL: documentURL, sceneURL: sceneURL) else {
		return
	}
	let workspaceURL = documentURL.appendingPathComponent(DeconstructedConstants.DirectoryName.workspaceData)
	let userDataURL = resolveUserDataURL(in: workspaceURL)
	var rootObject = loadJSONDictionary(url: userDataURL) ?? [:]

	var historyByScene = rootObject[RCUserDataKeys.sceneCameraHistory] as? [String: Any] ?? [:]
	var entries = historyByScene[sceneUUID] as? [[String: Any]] ?? []
	let entry: [String: Any] = [
		RCUserDataKeys.date: date.timeIntervalSinceReferenceDate,
		RCUserDataKeys.title: title,
		RCUserDataKeys.transform: transform
	]
	entries.append(entry)
	historyByScene[sceneUUID] = entries
	rootObject[RCUserDataKeys.sceneCameraHistory] = historyByScene

	try writeJSONDictionary(rootObject, to: userDataURL)
}

private let cameraHistoryMaxEntries: Int = 20

private func loadSettingsGridVisible(documentURL: URL) -> Bool? {
	let settingsURL = documentURL.appendingPathComponent("WorkspaceData/Settings.rcprojectdata")
	guard let data = try? Data(contentsOf: settingsURL),
	      let settings = try? JSONDecoder().decode(RCPSettings.self, from: data) else {
		return nil
	}
	return settings.secondaryToolbarData.isGridVisible
}

private func updateSettingsGridVisible(documentURL: URL, isVisible: Bool) throws {
	let settingsURL = documentURL.appendingPathComponent("WorkspaceData/Settings.rcprojectdata")
	var settings: RCPSettings
	if let data = try? Data(contentsOf: settingsURL),
	   let decoded = try? JSONDecoder().decode(RCPSettings.self, from: data) {
		settings = decoded
	} else {
		settings = RCPSettings.initial()
	}
	settings.secondaryToolbarData.isGridVisible = isVisible
	let encoder = JSONEncoder()
	encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
	let data = try encoder.encode(settings)
	try data.write(to: settingsURL, options: .atomic)
}

private func resolveUserDataURL(in workspaceURL: URL) -> URL {
	if let existing = (try? FileManager.default.contentsOfDirectory(
		at: workspaceURL,
		includingPropertiesForKeys: nil
	))?.first(where: { $0.pathExtension == "rcuserdata" }) {
		return existing
	}
	let username = NSUserName()
	return workspaceURL.appendingPathComponent(
		DeconstructedConstants.PathPattern.userDataFile(username: username)
	)
}

private func findUserDataURL(in workspaceURL: URL) -> URL? {
	let username = NSUserName()
	let preferred = workspaceURL.appendingPathComponent(
		DeconstructedConstants.PathPattern.userDataFile(username: username)
	)
	if FileManager.default.fileExists(atPath: preferred.path) {
		return preferred
	}
	if let existing = (try? FileManager.default.contentsOfDirectory(
		at: workspaceURL,
		includingPropertiesForKeys: nil
	))?.first(where: { $0.pathExtension == DeconstructedConstants.FileExtension.rcuserdata }) {
		return existing
	}
	return nil
}

private func relativeScenePath(_ sceneURL: URL, rkassetsURL: URL?) -> String {
	guard let rkassetsURL else {
		return sceneURL.lastPathComponent
	}
	let rootComponents = rkassetsURL.standardizedFileURL.pathComponents
	let fileComponents = sceneURL.standardizedFileURL.pathComponents
	guard fileComponents.starts(with: rootComponents) else {
		return sceneURL.lastPathComponent
	}
	let relativeComponents = fileComponents.dropFirst(rootComponents.count)
	let path = relativeComponents.joined(separator: "/")
	return path.isEmpty ? sceneURL.lastPathComponent : path
}

private func sceneURL(fromRelativePath path: String, rkassetsURL: URL?) -> URL? {
	guard let rkassetsURL else { return nil }
	var url = rkassetsURL
	for component in path.split(separator: "/") {
		url.appendPathComponent(String(component))
	}
	return url.standardizedFileURL
}

private func findRKAssets(for documentURL: URL) -> URL? {
	let parentURL = documentURL.deletingLastPathComponent()
	let sourcesURL = parentURL.appendingPathComponent(DeconstructedConstants.DirectoryName.sources)
	guard let contents = try? FileManager.default.contentsOfDirectory(
		at: sourcesURL,
		includingPropertiesForKeys: [.isDirectoryKey]
	) else {
		return nil
	}
	for projectDir in contents {
		let isDir = (try? projectDir.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
		guard isDir else { continue }
		if let inner = try? FileManager.default.contentsOfDirectory(
			at: projectDir,
			includingPropertiesForKeys: [.isDirectoryKey]
		) {
			for item in inner {
				if item.pathExtension == DeconstructedConstants.FileExtension.rkassets {
					let isItemDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
					if isItemDir { return item }
				}
			}
		}
	}
	return nil
}

private func sceneUUIDForURL(documentURL: URL, sceneURL: URL) -> String? {
	let mainJsonURL = documentURL
		.appendingPathComponent(DeconstructedConstants.DirectoryName.projectData)
		.appendingPathComponent(DeconstructedConstants.FileName.mainJson)
	guard let data = try? Data(contentsOf: mainJsonURL),
	      let projectData = try? JSONDecoder().decode(RCPProjectData.self, from: data) else {
		return nil
	}
	let rootURL = documentURL.deletingLastPathComponent()
	let rootComponents = rootURL.standardizedFileURL.pathComponents
	let fileComponents = sceneURL.standardizedFileURL.pathComponents
	guard fileComponents.starts(with: rootComponents) else {
		return nil
	}
	let relativeComponents = Array(fileComponents.dropFirst(rootComponents.count))
	guard !relativeComponents.isEmpty else { return nil }

	for (path, uuid) in projectData.pathsToIds {
		let components = path
			.split(separator: "/")
			.map { String($0) }
			.map { $0.removingPercentEncoding ?? $0 }
		guard components.count >= relativeComponents.count else { continue }
		if components.suffix(relativeComponents.count).elementsEqual(relativeComponents) {
			return uuid
		}
	}
	return nil
}

private enum RCUserDataKeys {
	static let openSceneRelativePaths = DeconstructedConstants.JSONKey.openSceneRelativePaths
	static let selectedSceneRelativePath = DeconstructedConstants.JSONKey.selectedSceneRelativePath
	static let sceneCameraHistory = DeconstructedConstants.JSONKey.sceneCameraHistory
	static let date = DeconstructedConstants.JSONKey.date
	static let title = DeconstructedConstants.JSONKey.title
	static let transform = DeconstructedConstants.JSONKey.transform
}

private func loadJSONDictionary(url: URL) -> [String: Any]? {
	guard let data = try? Data(contentsOf: url) else { return nil }
	return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
}

private func writeJSONDictionary(_ object: [String: Any], to url: URL) throws {
	let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
	try data.write(to: url, options: .atomic)
}
