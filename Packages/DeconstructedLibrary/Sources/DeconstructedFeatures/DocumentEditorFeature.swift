import ComposableArchitecture
import DeconstructedModels
import Foundation
import InspectorFeature
import ProjectBrowserFeature
import SceneGraphFeature
import ViewportModels

/// Represents an open scene tab with its viewport state
public struct SceneTab: Equatable, Identifiable {
    public let id: UUID
    public let fileURL: URL
    public let displayName: String
	public var cameraTransform: [Float]?
	public var cameraTransformRequestID: UUID?
	public var frameRequestID: UUID?
	/// Trigger to force viewport reload when scene is modified
	public var reloadTrigger: UUID?
    
    public init(
		fileURL: URL,
		cameraTransform: [Float]? = nil,
		cameraTransformRequestID: UUID? = nil,
		frameRequestID: UUID? = nil,
		reloadTrigger: UUID? = nil
	) {
        self.id = UUID()
        let normalized = normalizedSceneURL(fileURL)
        self.fileURL = normalized
        self.displayName = normalized.lastPathComponent
		self.cameraTransform = cameraTransform
		self.cameraTransformRequestID = cameraTransformRequestID
		self.frameRequestID = frameRequestID
		self.reloadTrigger = reloadTrigger
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
        public var sceneNavigator: SceneGraphFeature.State
        public var inspector: InspectorFeature.State
        public var viewportShowGrid: Bool
        public var cameraHistory: [CameraHistoryItem]
        public var pendingCameraHistory: PendingCameraHistory?

        // Environment
        public var environmentPath: String?
        public var environmentShowBackground: Bool
        public var environmentRotation: Float
        public var environmentExposure: Float

        public init(
            selectedTab: EditorTab? = nil,
            selectedBottomTab: BottomTab = .projectBrowser,
            openScenes: IdentifiedArrayOf<SceneTab> = [],
            projectBrowser: ProjectBrowserFeature.State = ProjectBrowserFeature.State(),
            sceneNavigator: SceneGraphFeature.State = SceneGraphFeature.State(),
            inspector: InspectorFeature.State = InspectorFeature.State(),
            viewportShowGrid: Bool = true,
            cameraHistory: [CameraHistoryItem] = [],
            pendingCameraHistory: PendingCameraHistory? = nil,
            environmentPath: String? = nil,
            environmentShowBackground: Bool = true,
            environmentRotation: Float = 0,
            environmentExposure: Float = 0
        ) {
            self.selectedTab = selectedTab
            self.selectedBottomTab = selectedBottomTab
            self.openScenes = openScenes
            self.projectBrowser = projectBrowser
            self.sceneNavigator = sceneNavigator
            self.inspector = inspector
            self.viewportShowGrid = viewportShowGrid
            self.cameraHistory = cameraHistory
            self.pendingCameraHistory = pendingCameraHistory
            self.environmentPath = environmentPath
            self.environmentShowBackground = environmentShowBackground
            self.environmentRotation = environmentRotation
            self.environmentExposure = environmentExposure
        }
    }
    
    public enum Action {
  case documentOpened(URL)
  case workspaceRestored(WorkspaceRestore)
  case cameraHistoryLoaded([CameraHistoryItem])
  case gridVisibilityLoaded(Bool)
        case tabSelected(EditorTab?)
        case bottomTabSelected(BottomTab)
        case sceneOpened(URL)
        case sceneClosed(UUID)
  case sceneCameraChanged(URL, [Float])
  case cameraHistoryCommit(URL, [Float])
  case frameSceneRequested
  case frameSelectedRequested
  case toggleGridRequested
        case cameraHistorySelected(CameraHistoryItem.ID)
        case projectBrowser(ProjectBrowserFeature.Action)
        case sceneNavigator(SceneGraphFeature.Action)
        case inspector(InspectorFeature.Action)
        /// Triggered when scene is modified (e.g., prim added) to force viewport reload
        case sceneModified(UUID)

  // Environment
  case environmentPathChanged(String?)
  case environmentShowBackgroundChanged(Bool)
  case environmentRotationChanged(Float)
  case environmentExposureChanged(Float)
    }
    
    public init() {}

	@Dependency(\.continuousClock) var clock
    
    public var body: some ReducerOf<Self> {
        Scope(state: \.projectBrowser, action: \.projectBrowser) {
            ProjectBrowserFeature()
        }
        Scope(state: \.sceneNavigator, action: \.sceneNavigator) {
            SceneGraphFeature()
        }
        Scope(state: \.inspector, action: \.inspector) {
            InspectorFeature()
        }

        Reduce { state, action in
            switch action {
			case let .documentOpened(documentURL):
				return .run { send in
					if let restored = loadWorkspaceRestore(documentURL: documentURL) {
						await send(.workspaceRestored(restored))
					}
					if let gridVisible = loadSettingsGridVisible(documentURL: documentURL) {
						await send(.gridVisibilityLoaded(gridVisible))
					}
				}

			case let .workspaceRestored(restored):
				state.openScenes = IdentifiedArray(
					uniqueElements: restored.openSceneURLs.map { url in
						SceneTab(
							fileURL: url,
							cameraTransform: restored.cameraTransforms[url],
							cameraTransformRequestID: restored.cameraTransforms[url] == nil ? nil : UUID()
						)
					}
				)
				if let selected = restored.selectedSceneURL,
				   let selectedTab = state.openScenes.first(where: { $0.fileURL == selected }) {
					state.selectedTab = .scene(id: selectedTab.id)
				} else {
					state.selectedTab = nil
				}
				let selectedScene = selectedSceneURL(state: state)
				state.sceneNavigator.sceneURL = selectedScene
				guard let documentURL = state.projectBrowser.documentURL,
				      let selectedURL = selectedScene else {
					state.cameraHistory = []
					return .merge(
						.send(.sceneNavigator(.sceneURLChanged(nil))),
						.send(.inspector(.sceneURLChanged(nil))),
						.send(.inspector(.selectionChanged(nil)))
					)
				}
				return .merge(
					loadCameraHistoryEffect(documentURL: documentURL, sceneURL: selectedURL),
					.send(.sceneNavigator(.sceneURLChanged(selectedURL))),
					.send(.inspector(.sceneURLChanged(selectedURL))),
					.send(.inspector(.selectionChanged(nil)))
				)

			case let .cameraHistoryLoaded(items):
				state.cameraHistory = items
				return .none

			case let .gridVisibilityLoaded(isVisible):
				state.viewportShowGrid = isVisible
				return .none

            case let .tabSelected(tab):
                state.selectedTab = tab
				if let documentURL = state.projectBrowser.documentURL,
				   let selectedURL = selectedSceneURL(state: state) {
					return .merge(
						updateUserDataEffect(state: state),
						loadCameraHistoryEffect(documentURL: documentURL, sceneURL: selectedURL),
						.send(.sceneNavigator(.sceneURLChanged(selectedURL))),
						.send(.inspector(.sceneURLChanged(selectedURL))),
						.send(.inspector(.selectionChanged(nil)))
					)
				}
				state.cameraHistory = []
				return .merge(
					updateUserDataEffect(state: state),
					.send(.sceneNavigator(.sceneURLChanged(nil))),
					.send(.inspector(.sceneURLChanged(nil)))
				)
                
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
				if let documentURL = state.projectBrowser.documentURL {
					return .merge(
						updateUserDataEffect(state: state),
						loadCameraHistoryEffect(documentURL: documentURL, sceneURL: normalizedURL),
						.send(.sceneNavigator(.sceneURLChanged(normalizedURL))),
						.send(.inspector(.sceneURLChanged(normalizedURL))),
						.send(.inspector(.selectionChanged(nil)))
					)
				}
				return .merge(
					updateUserDataEffect(state: state),
					.send(.sceneNavigator(.sceneURLChanged(normalizedURL))),
					.send(.inspector(.sceneURLChanged(normalizedURL))),
					.send(.inspector(.selectionChanged(nil)))
				)
			}
			
			// Open new scene
			let newTab = SceneTab(fileURL: normalizedURL)
			print("[DocumentEditorFeature] Created new tab: \(newTab.id)")
			state.openScenes.append(newTab)
			state.selectedTab = .scene(id: newTab.id)
			print("[DocumentEditorFeature] Total open scenes: \(state.openScenes.count)")
			if let documentURL = state.projectBrowser.documentURL {
				return .merge(
					updateUserDataEffect(state: state),
					loadCameraHistoryEffect(documentURL: documentURL, sceneURL: normalizedURL),
					.send(.sceneNavigator(.sceneURLChanged(normalizedURL))),
					.send(.inspector(.sceneURLChanged(normalizedURL))),
					.send(.inspector(.selectionChanged(nil)))
				)
			}
			return .merge(
				updateUserDataEffect(state: state),
				.send(.sceneNavigator(.sceneURLChanged(normalizedURL))),
				.send(.inspector(.sceneURLChanged(normalizedURL))),
				.send(.inspector(.selectionChanged(nil)))
			)
                
			case let .sceneClosed(id):
                state.openScenes.remove(id: id)
                if case .scene(let selectedId) = state.selectedTab, selectedId == id {
                    if let next = state.openScenes.first {
                        state.selectedTab = .scene(id: next.id)
                    } else {
                        state.selectedTab = nil
                    }
                }
				if let documentURL = state.projectBrowser.documentURL,
				   let selectedURL = selectedSceneURL(state: state) {
					return .merge(
						updateUserDataEffect(state: state),
						loadCameraHistoryEffect(documentURL: documentURL, sceneURL: selectedURL),
						.send(.sceneNavigator(.sceneURLChanged(selectedURL))),
						.send(.inspector(.sceneURLChanged(selectedURL))),
						.send(.inspector(.selectionChanged(nil)))
					)
				}
				state.cameraHistory = []
                return .merge(
					updateUserDataEffect(state: state),
					.send(.sceneNavigator(.sceneURLChanged(nil))),
					.send(.inspector(.sceneURLChanged(nil))),
					.send(.inspector(.selectionChanged(nil)))
				)

			case let .sceneCameraChanged(url, transform):
				guard let documentURL = state.projectBrowser.documentURL else {
					return .none
				}
				let title = url.deletingPathExtension().lastPathComponent
				let clock = self.clock
				if case .scene(let id) = state.selectedTab,
				   var tab = state.openScenes[id: id],
				   tab.fileURL == url {
					tab.cameraTransform = transform
					state.openScenes[id: id] = tab
				}
				state.pendingCameraHistory = PendingCameraHistory(
					documentURL: documentURL,
					sceneURL: url,
					title: title,
					transform: transform
				)
				return .run { send in
					try await clock.sleep(for: cameraHistoryDebounceInterval)
					await send(.cameraHistoryCommit(url, transform))
				}
				.cancellable(id: CameraHistoryDebounceId.write, cancelInFlight: true)

			case let .cameraHistoryCommit(url, transform):
				guard let documentURL = state.projectBrowser.documentURL else {
					return .none
				}
				let title = url.deletingPathExtension().lastPathComponent
				let entry = CameraHistoryItem(
					date: Date(),
					title: title,
					transform: transform
				)
				if shouldAppendCameraHistory(entry, to: state.cameraHistory) {
					state.cameraHistory.append(entry)
					if state.cameraHistory.count > cameraHistoryMaxEntries {
						state.cameraHistory.removeFirst(state.cameraHistory.count - cameraHistoryMaxEntries)
					}
				}
				state.pendingCameraHistory = nil
				return .run { _ in
					try? updateSceneCameraHistory(
						documentURL: documentURL,
						sceneURL: url,
						title: title,
						transform: transform
					)
				}

			case .frameSceneRequested, .frameSelectedRequested:
				guard case .scene(let id) = state.selectedTab,
				      var tab = state.openScenes[id: id] else {
					return .none
				}
				tab.frameRequestID = UUID()
				state.openScenes[id: id] = tab
				return .none

			case .toggleGridRequested:
				state.viewportShowGrid.toggle()
				guard let documentURL = state.projectBrowser.documentURL else {
					return .none
				}
				let isVisible = state.viewportShowGrid
				return .run { _ in
					try? updateSettingsGridVisible(documentURL: documentURL, isVisible: isVisible)
				}

			case let .cameraHistorySelected(id):
				guard case .scene(let selectedId) = state.selectedTab,
				      var tab = state.openScenes[id: selectedId],
				      let item = state.cameraHistory.first(where: { $0.id == id }) else {
					return .none
				}
				tab.cameraTransform = item.transform
				tab.cameraTransformRequestID = UUID()
				state.openScenes[id: selectedId] = tab
				return .none
                
            case .projectBrowser:
                          return .none
          
            case .sceneNavigator(let sceneAction):
				var effects: [Effect<Action>] = []
				
				// Detect when scene is modified (prim created) to trigger viewport reload
				if case .primCreated = sceneAction,
				   case .scene(let tabID) = state.selectedTab,
				   var tab = state.openScenes[id: tabID] {
					tab.reloadTrigger = UUID()
					state.openScenes[id: tabID] = tab
					// Also invalidate thumbnail for this scene via ProjectBrowserFeature
					effects.append(.send(.projectBrowser(.sceneModified(tab.fileURL))))
				}
				
				// Forward selection changes to inspector
				if case .selectionChanged(let nodeID) = sceneAction {
					effects.append(.send(.inspector(.selectionChanged(nodeID))))
				}
				
				// Forward scene graph loaded to inspector for available prims
				if case .sceneGraphLoaded(_, let nodes) = sceneAction {
					effects.append(.send(.inspector(.sceneGraphUpdated(nodes))))
				}
				
				return effects.isEmpty ? .none : .merge(effects)

			case .inspector:
				return .none
          
            case let .sceneModified(tabID):
            	if var tab = state.openScenes[id: tabID] {
            		tab.reloadTrigger = UUID()
            		state.openScenes[id: tabID] = tab
            	}
            	return .none

			case let .environmentPathChanged(path):
				state.environmentPath = path
				return .none

			case let .environmentShowBackgroundChanged(show):
				state.environmentShowBackground = show
				return .none

			case let .environmentRotationChanged(rotation):
				state.environmentRotation = rotation
				return .none

			case let .environmentExposureChanged(exposure):
				state.environmentExposure = exposure
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

public struct CameraHistoryItem: Equatable, Identifiable, Sendable {
	public let id: UUID
	public let date: Date
	public let title: String
	public let transform: [Float]

	public init(date: Date, title: String, transform: [Float]) {
		self.id = UUID()
		self.date = date
		self.title = title
		self.transform = transform
	}

	public var displayName: String {
		let formatter = DateFormatter()
		formatter.dateStyle = .none
		formatter.timeStyle = .short
		return "\(title) — \(formatter.string(from: date))"
	}
}

public struct PendingCameraHistory: Equatable, Sendable {
	public let documentURL: URL
	public let sceneURL: URL
	public let title: String
	public let transform: [Float]
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

private func selectedSceneURL(state: DocumentEditorFeature.State) -> URL? {
	if case .scene(let id) = state.selectedTab,
	   let tab = state.openScenes[id: id] {
		return tab.fileURL
	}
	return nil
}

private func loadCameraHistoryEffect(
	documentURL: URL,
	sceneURL: URL
) -> Effect<DocumentEditorFeature.Action> {
	.run { send in
		let items = loadCameraHistory(documentURL: documentURL, sceneURL: sceneURL)
		await send(.cameraHistoryLoaded(items))
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

private func shouldAppendCameraHistory(
	_ entry: CameraHistoryItem,
	to history: [CameraHistoryItem]
) -> Bool {
	guard let last = history.last else { return true }
	let delta = maxAbsDelta(entry.transform, last.transform)
	let timeDelta = entry.date.timeIntervalSince(last.date)
	return delta >= cameraHistoryTransformThreshold || timeDelta >= cameraHistoryMinInterval
}

private func maxAbsDelta(_ lhs: [Float], _ rhs: [Float]) -> Float {
	guard lhs.count == rhs.count else { return .infinity }
	var maxDelta: Float = 0
	for (a, b) in zip(lhs, rhs) {
		let delta = abs(a - b)
		if delta > maxDelta {
			maxDelta = delta
		}
	}
	return maxDelta
}

private let cameraHistoryDebounceInterval: Duration = .seconds(1)
private let cameraHistoryMinInterval: TimeInterval = 2
private let cameraHistoryTransformThreshold: Float = 0.001
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
