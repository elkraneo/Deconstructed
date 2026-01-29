import ComposableArchitecture
import DeconstructedModels
import DeconstructedModels
import Foundation
import ProjectBrowserFeature
import ViewportModels

/// Represents an open scene tab with its viewport state
public struct SceneTab: Equatable, Identifiable {
    public let id: UUID
    public let fileURL: URL
    public let displayName: String
	public let cameraTransform: [Float]?
    
    public init(fileURL: URL, cameraTransform: [Float]? = nil) {
        self.id = UUID()
        let normalized = normalizedSceneURL(fileURL)
        self.fileURL = normalized
        self.displayName = normalized.lastPathComponent
		self.cameraTransform = cameraTransform
    }
}

/// Bottom panel tab types
public enum BottomTab: Equatable, Hashable {
    case projectBrowser
    case shaderGraph
    case timeline
    case audio
    case statistics
    case debug
    
    public var id: String {
        switch self {
        case .projectBrowser: return "projectBrowser"
        case .shaderGraph: return "shaderGraph"
        case .timeline: return "timeline"
        case .audio: return "audio"
        case .statistics: return "statistics"
        case .debug: return "debug"
        }
    }
    
    public var displayName: String {
        switch self {
        case .projectBrowser: return "Project Browser"
        case .shaderGraph: return "Shader Graph"
        case .timeline: return "Timelines"
        case .audio: return "Audio Mixer"
        case .statistics: return "Statistics"
        case .debug: return "Debug Info"
        }
    }
    
    public var icon: String {
        switch self {
        case .projectBrowser: return "square.grid.2x2"
        case .shaderGraph: return "circle.hexagongrid"
        case .timeline: return "clock"
        case .audio: return "waveform"
        case .statistics: return "chart.bar"
        case .debug: return "ladybug"
        }
    }
}

/// Scene tab identifier
public enum EditorTab: Equatable, Hashable {
    case scene(id: UUID)
}

@Reducer
public struct DocumentEditorFeature {
    @ObservableState
    public struct State: Equatable {
        public var selectedTab: EditorTab?  // nil means no scene selected
        public var selectedBottomTab: BottomTab
        public var openScenes: IdentifiedArrayOf<SceneTab>
        public var projectBrowser: ProjectBrowserFeature.State
        
        public init(
            selectedTab: EditorTab? = nil,
            selectedBottomTab: BottomTab = .projectBrowser,
            openScenes: IdentifiedArrayOf<SceneTab> = [],
            projectBrowser: ProjectBrowserFeature.State = ProjectBrowserFeature.State()
        ) {
            self.selectedTab = selectedTab
            self.selectedBottomTab = selectedBottomTab
            self.openScenes = openScenes
            self.projectBrowser = projectBrowser
        }
    }
    
    public enum Action {
		case documentOpened(URL)
		case workspaceRestored(WorkspaceRestore)
        case tabSelected(EditorTab?)
        case bottomTabSelected(BottomTab)
        case sceneOpened(URL)
        case sceneClosed(UUID)
		case sceneCameraChanged(URL, [Float])
        case projectBrowser(ProjectBrowserFeature.Action)
    }
    
    public init() {}

	@Dependency(\.continuousClock) var clock
    
    public var body: some ReducerOf<Self> {
        Scope(state: \.projectBrowser, action: \.projectBrowser) {
            ProjectBrowserFeature()
        }
        
        Reduce { state, action in
            switch action {
			case let .documentOpened(documentURL):
				return .run { send in
					if let restored = loadWorkspaceRestore(documentURL: documentURL) {
						await send(.workspaceRestored(restored))
					}
				}

			case let .workspaceRestored(restored):
				state.openScenes = IdentifiedArray(
					uniqueElements: restored.openSceneURLs.map { url in
						SceneTab(fileURL: url, cameraTransform: restored.cameraTransforms[url])
					}
				)
				if let selected = restored.selectedSceneURL,
				   let selectedTab = state.openScenes.first(where: { $0.fileURL == selected }) {
					state.selectedTab = .scene(id: selectedTab.id)
				} else {
					state.selectedTab = nil
				}
				return .none

            case let .tabSelected(tab):
                state.selectedTab = tab
				return updateUserDataEffect(state: state)
                
            case let .bottomTabSelected(tab):
                state.selectedBottomTab = tab
                return .none
                
			case let .sceneOpened(url):
				let normalizedURL = normalizedSceneURL(url)
				print("[DocumentEditorFeature] Opening scene: \(normalizedURL.lastPathComponent)")
				// Check if already open
				if let existing = state.openScenes.first(where: { $0.fileURL == normalizedURL }) {
					print("[DocumentEditorFeature] Scene already open, switching to tab")
					state.selectedTab = .scene(id: existing.id)
					return updateUserDataEffect(state: state)
				}
				
				// Open new scene
				let newTab = SceneTab(fileURL: normalizedURL)
				print("[DocumentEditorFeature] Created new tab: \(newTab.id)")
				state.openScenes.append(newTab)
				state.selectedTab = .scene(id: newTab.id)
				print("[DocumentEditorFeature] Total open scenes: \(state.openScenes.count)")
				return updateUserDataEffect(state: state)
                
            case let .sceneClosed(id):
                state.openScenes.remove(id: id)
                if case .scene(let selectedId) = state.selectedTab, selectedId == id {
                    if let next = state.openScenes.first {
                        state.selectedTab = .scene(id: next.id)
                    } else {
                        state.selectedTab = nil
                    }
                }
                return updateUserDataEffect(state: state)

			case let .sceneCameraChanged(url, transform):
				guard let documentURL = state.projectBrowser.documentURL else {
					return .none
				}
				let title = url.deletingPathExtension().lastPathComponent
				let clock = self.clock
				return .run { _ in
					try await clock.sleep(for: .milliseconds(300))
					try? updateSceneCameraHistory(
						documentURL: documentURL,
						sceneURL: url,
						title: title,
						transform: transform
					)
				}
				.cancellable(id: CameraHistoryDebounceId.write, cancelInFlight: true)
                
            case .projectBrowser:
                return .none
            }
        }
    }
}

private func normalizedSceneURL(_ url: URL) -> URL {
    URL(fileURLWithPath: url.path).standardizedFileURL
}

public struct WorkspaceRestore: Sendable, Equatable {
	let openSceneURLs: [URL]
	let selectedSceneURL: URL?
	let cameraTransforms: [URL: [Float]]
}

private func updateUserDataEffect(state: DocumentEditorFeature.State) -> Effect<DocumentEditorFeature.Action> {
	guard let documentURL = state.projectBrowser.documentURL else {
		return .none
	}
	let openScenes = state.openScenes.map(\.fileURL)
	let selectedURL: URL?
	if case .scene(let id) = state.selectedTab,
	   let tab = state.openScenes[id: id] {
		selectedURL = tab.fileURL
	} else {
		selectedURL = nil
	}
	return .run { _ in
		try? updateUserData(
			documentURL: documentURL,
			openSceneURLs: openScenes,
			selectedSceneURL: selectedURL
		)
	}
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
	transform: [Float]
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
		RCUserDataKeys.date: Date().timeIntervalSinceReferenceDate,
		RCUserDataKeys.title: title,
		RCUserDataKeys.transform: transform
	]
	entries.append(entry)
	historyByScene[sceneUUID] = entries
	rootObject[RCUserDataKeys.sceneCameraHistory] = historyByScene

	try writeJSONDictionary(rootObject, to: userDataURL)
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

// MARK: - RCUserData Keys

/// Known keys for `.rcuserdata` JSON files.
///
/// We extract these into constants to prevent typos while preserving the dynamic
/// dictionary-based approach. This gives us partial type safety without the overhead
/// of a full Codable model.
private enum RCUserDataKeys {
	static let openSceneRelativePaths = DeconstructedConstants.JSONKey.openSceneRelativePaths
	static let selectedSceneRelativePath = DeconstructedConstants.JSONKey.selectedSceneRelativePath
	static let sceneCameraHistory = DeconstructedConstants.JSONKey.sceneCameraHistory

	// Entry keys for camera history records
	static let date = DeconstructedConstants.JSONKey.date
	static let title = DeconstructedConstants.JSONKey.title
	static let transform = DeconstructedConstants.JSONKey.transform
}

// MARK: - JSON Dictionary Helpers

/// Loads a JSON file as a dynamic dictionary.
///
/// ## Why JSONSerialization over Codable?
///
/// The `*.rcuserdata` files are **loose, user-specific JSON blobs** with an evolving schema
/// controlled by Apple's Reality Composer. We use `JSONSerialization` + `[String: Any]`
/// instead of `Codable` for several important reasons:
///
/// 1. **Preserves unknown keys**: RCUserData may contain keys we don't model (e.g., future
///    additions by Apple). `JSONSerialization` round-trips these perfectly, whereas a strict
///    `Codable` struct would drop them → **data loss**.
///
/// 2. **Partial updates**: We only need to read/write a few known fields while preserving
///    everything else exactly as-is. This is trivial with dictionaries:
///    ```swift
///    dict[RCUserDataKeys.selectedSceneRelativePath] = newPath
///    // All other keys remain untouched
///    ```
///
/// 3. **Avoids brittle Codable scaffolding**: To achieve the same with `Codable`, we'd need
///    either a passthrough `additionalProperties: [String: AnyCodable]` dictionary or a
///    custom `init(from:)/encode(to:)` implementation—both add complexity with little gain.
///
/// **Trade-off**: We lose compile-time type checking for the entire structure, but the
/// `RCUserDataKeys` enum above mitigates key-name typos. This is an acceptable balance for
/// a foreign JSON format we don't own.
///
/// - Parameter url: The file URL to read from.
/// - Returns: The parsed dictionary, or `nil` if the file doesn't exist or isn't valid JSON.
private func loadJSONDictionary(url: URL) -> [String: Any]? {
	guard let data = try? Data(contentsOf: url) else { return nil }
	return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
}

/// Writes a dictionary back to a JSON file atomically.
///
/// See `loadJSONDictionary(url:)` for rationale on using `JSONSerialization` over `Codable`.
///
/// - Parameters:
///   - object: The dictionary to serialize.
///   - url: The destination file URL.
/// - Throws: If serialization or file writing fails.
private func writeJSONDictionary(_ object: [String: Any], to url: URL) throws {
	let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
	try data.write(to: url, options: .atomic)
}

private enum CameraHistoryDebounceId: Hashable {
	case write
}
