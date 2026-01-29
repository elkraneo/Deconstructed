import ComposableArchitecture
import Foundation
import Testing
@testable import DeconstructedFeatures
@testable import ProjectBrowserFeature
@testable import ProjectBrowserModels
@testable import DeconstructedModels

@MainActor
struct DocumentEditorFeatureTests {
	@Test
	func userData_preservesUnknownKeys_andUpdatesOpenScenes() async throws {
		let tempRoot = try makeTempDirectory()
		defer { try? FileManager.default.removeItem(at: tempRoot) }

		let documentURL = tempRoot.appendingPathComponent("Project.realitycomposerpro")
		try createDirectory(documentURL)
		try createDirectory(documentURL.appendingPathComponent("WorkspaceData"))

		let sourcesURL = tempRoot.appendingPathComponent("Sources/MyProject/MyProject.rkassets")
		try createDirectory(sourcesURL)

		let sceneA = sourcesURL.appendingPathComponent("Scene.usda")
		let sceneB = sourcesURL.appendingPathComponent("Other.usda")
		FileManager.default.createFile(atPath: sceneA.path, contents: Data())
		FileManager.default.createFile(atPath: sceneB.path, contents: Data())

		let userDataURL = documentURL
			.appendingPathComponent("WorkspaceData")
			.appendingPathComponent("tester.rcuserdata")
		let seed: [String: Any] = [
			"advancedEditorSelectedIdentifier": "ProjectBrowser",
			"customMetadata": ["keep": true]
		]
		try writeJSON(seed, to: userDataURL)

		var state = DocumentEditorFeature.State()
		state.projectBrowser.documentURL = documentURL

		let store = TestStore(initialState: state) {
			DocumentEditorFeature()
		}
		store.exhaustivity = .off

		await store.send(.sceneOpened(sceneA))
		await Task.yield()
		await store.send(.sceneOpened(sceneB))
		await Task.yield()

		let updated = try readJSON(from: userDataURL)
		let openPaths = updated["openSceneRelativePaths"] as? [String]
		let selectedPath = updated["selectedSceneRelativePath"] as? String
		let custom = updated["customMetadata"] as? [String: Any]

		#expect(openPaths == ["Scene.usda", "Other.usda"])
		#expect(selectedPath == "Other.usda")
		#expect(custom?["keep"] as? Bool == true)
	}

	@Test
	func sceneCameraHistory_appendsTransformEntry() async throws {
		let tempRoot = try makeTempDirectory()
		defer { try? FileManager.default.removeItem(at: tempRoot) }

		let documentURL = tempRoot.appendingPathComponent("Project.realitycomposerpro")
		try createDirectory(documentURL)
		try createDirectory(documentURL.appendingPathComponent("WorkspaceData"))
		try createDirectory(documentURL.appendingPathComponent("ProjectData"))

		let sourcesURL = tempRoot.appendingPathComponent("Sources/MyProject/MyProject.rkassets")
		try createDirectory(sourcesURL)

		let sceneURL = sourcesURL.appendingPathComponent("Scene.usda")
		FileManager.default.createFile(atPath: sceneURL.path, contents: Data())

		let sceneUUID = UUID().uuidString
		let pathKey = "Sources/MyProject/MyProject.rkassets/Scene.usda"
		let projectData = RCPProjectData(
			pathsToIds: [pathKey: sceneUUID],
			projectID: 1,
			uuidToIntID: [sceneUUID: 2]
		)
		let encoder = JSONEncoder()
		encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
		let mainData = try encoder.encode(projectData)
		try mainData.write(
			to: documentURL.appendingPathComponent("ProjectData/main.json"),
			options: .atomic
		)

		let userDataURL = documentURL
			.appendingPathComponent("WorkspaceData")
			.appendingPathComponent("tester.rcuserdata")
		try writeJSON(["sceneCameraHistory": [:]], to: userDataURL)

		var state = DocumentEditorFeature.State()
		state.projectBrowser.documentURL = documentURL

		let clock = TestClock()
		let store = TestStore(initialState: state) {
			DocumentEditorFeature()
		} withDependencies: {
			$0.continuousClock = clock
		}

		let transform = Array(repeating: Float(1.0), count: 16)
		await store.send(.sceneCameraChanged(sceneURL, transform))
		await clock.advance(by: .milliseconds(300))
		await Task.yield()

		let updated = try readJSON(from: userDataURL)
		let history = updated["sceneCameraHistory"] as? [String: Any]
		let entries = history?[sceneUUID] as? [[String: Any]]
		let last = entries?.last
		let stored = last?["transform"] as? [Double]

		#expect(stored?.count == 16)
	}

	@Test
	func createScene_updatesSceneMetadata_andPluginData() async throws {
		let tempRoot = try makeTempDirectory()
		defer { try? FileManager.default.removeItem(at: tempRoot) }

		let documentURL = tempRoot.appendingPathComponent("Project.realitycomposerpro")
		try createDirectory(documentURL)
		try createDirectory(documentURL.appendingPathComponent("WorkspaceData"))
		try createDirectory(documentURL.appendingPathComponent("ProjectData"))
		try createDirectory(documentURL.appendingPathComponent("PluginData"))

		let sourcesURL = tempRoot.appendingPathComponent("Sources/MyProject/MyProject.rkassets")
		try createDirectory(sourcesURL)

		let existingUUID = UUID().uuidString
		let existingPath = "/Sources/MyProject/MyProject.rkassets/Scene.usda"
		let projectData = RCPProjectData(
			pathsToIds: [existingPath: existingUUID],
			projectID: 1,
			uuidToIntID: [existingUUID: 2]
		)
		let encoder = JSONEncoder()
		encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
		let mainData = try encoder.encode(projectData)
		try mainData.write(
			to: documentURL.appendingPathComponent("ProjectData/main.json"),
			options: .atomic
		)

		let metadata = RCPSceneMetadataList.initial(sceneUUID: existingUUID)
		let metadataData = try metadata.encode()
		try metadataData.write(
			to: documentURL.appendingPathComponent("WorkspaceData/SceneMetadataList.json"),
			options: .atomic
		)

		let rkassetsRoot = AssetItem(
			name: "MyProject.rkassets",
			url: sourcesURL,
			isDirectory: true,
			fileType: .directory,
			children: []
		)

		var state = ProjectBrowserFeature.State()
		state.assetItems = [rkassetsRoot]
		state.currentDirectoryId = rkassetsRoot.id
		state.documentURL = documentURL

		let store = TestStore(initialState: state) {
			ProjectBrowserFeature()
		} withDependencies: {
			$0.fileOperationsClient.createScene = { parent, _ in
				let url = parent.appendingPathComponent("Untitled Scene.usda")
				FileManager.default.createFile(atPath: url.path, contents: Data())
				return url
			}
			$0.assetDiscoveryClient.discover = { _ in [rkassetsRoot] }
			$0.fileWatcherClient.watch = { _ in
				AsyncStream { continuation in
					continuation.finish()
				}
			}
		}

		await store.send(.createSceneTapped)
		await store.receive(.fileOperationCompleted)
		await store.receive(.loadAssets(documentURL: documentURL)) {
			$0.isLoading = true
			$0.errorMessage = nil
			$0.documentURL = documentURL
		}
		await store.receive(.assetsLoaded([rkassetsRoot])) {
			$0.isLoading = false
			$0.assetItems = [rkassetsRoot]
			$0.expandedDirectories = [rkassetsRoot.id]
			$0.isWatchingFiles = true
			$0.watchedDirectoryURL = rkassetsRoot.url
		}

		let updatedData = try Data(contentsOf: documentURL.appendingPathComponent("ProjectData/main.json"))
		let updated = try JSONDecoder().decode(RCPProjectData.self, from: updatedData)
		let newUUID = updated.pathsToIds.first(where: { $0.key.contains("Untitled") })?.value
		#expect(newUUID != nil)

		let metadataURL = documentURL.appendingPathComponent("WorkspaceData/SceneMetadataList.json")
		let metadataUpdated = try JSONDecoder().decode(RCPSceneMetadataList.self, from: Data(contentsOf: metadataURL))
		#expect(metadataUpdated.scenes[newUUID ?? ""] != nil)

		if let newUUID {
			let pluginFile = documentURL
				.appendingPathComponent("PluginData")
				.appendingPathComponent(newUUID)
				.appendingPathComponent("ShaderGraphEditorPluginID")
				.appendingPathComponent("ShaderGraphEditorPluginID")
			#expect(FileManager.default.fileExists(atPath: pluginFile.path))
		}
	}

	@Test
	func restoreWorkspace_opensScenes_selectsTab_andRestoresCamera() async throws {
		let tempRoot = try makeTempDirectory()
		defer { try? FileManager.default.removeItem(at: tempRoot) }

		let documentURL = tempRoot.appendingPathComponent("Project.realitycomposerpro")
		try createDirectory(documentURL)
		try createDirectory(documentURL.appendingPathComponent("WorkspaceData"))
		try createDirectory(documentURL.appendingPathComponent("ProjectData"))

		let sourcesURL = tempRoot.appendingPathComponent("Sources/MyProject/MyProject.rkassets")
		try createDirectory(sourcesURL)

		let sceneURL = sourcesURL.appendingPathComponent("Scene.usda")
		FileManager.default.createFile(atPath: sceneURL.path, contents: Data())

		let sceneUUID = UUID().uuidString
		let pathKey = "Sources/MyProject/MyProject.rkassets/Scene.usda"
		let projectData = RCPProjectData(
			pathsToIds: [pathKey: sceneUUID],
			projectID: 1,
			uuidToIntID: [sceneUUID: 2]
		)
		let encoder = JSONEncoder()
		encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
		let mainData = try encoder.encode(projectData)
		try mainData.write(
			to: documentURL.appendingPathComponent("ProjectData/main.json"),
			options: .atomic
		)

		let transform = Array(repeating: Float(2.0), count: 16)
		let userDataURL = documentURL
			.appendingPathComponent("WorkspaceData")
			.appendingPathComponent("tester.rcuserdata")
		let userData: [String: Any] = [
			"openSceneRelativePaths": ["Scene.usda"],
			"selectedSceneRelativePath": "Scene.usda",
			"sceneCameraHistory": [
				sceneUUID: [
					[
						"date": Date().timeIntervalSinceReferenceDate,
						"title": "Scene",
						"transform": transform
					]
				]
			]
		]
		try writeJSON(userData, to: userDataURL)

		var state = DocumentEditorFeature.State()
		state.projectBrowser.documentURL = documentURL

		let store = TestStore(initialState: state) {
			DocumentEditorFeature()
		}

		store.exhaustivity = .off
		await store.send(.documentOpened(documentURL))
		await store.receive(\.workspaceRestored)

		#expect(store.state.openScenes.count == 1)
		let tab = store.state.openScenes.first
		#expect(tab?.fileURL == sceneURL.standardizedFileURL)
		#expect(tab?.cameraTransform == transform)
		if let selected = store.state.selectedTab {
			if case .scene(let id) = selected {
				#expect(store.state.openScenes[id: id]?.fileURL == sceneURL.standardizedFileURL)
			}
		} else {
			#expect(Bool(false))
		}
	}
}

private func makeTempDirectory() throws -> URL {
	let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
	try createDirectory(temp)
	return temp
}

private func createDirectory(_ url: URL) throws {
	try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
}

private func writeJSON(_ object: [String: Any], to url: URL) throws {
	let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
	try data.write(to: url, options: .atomic)
}

private func readJSON(from url: URL) throws -> [String: Any] {
	let data = try Data(contentsOf: url)
	return (try JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
}
