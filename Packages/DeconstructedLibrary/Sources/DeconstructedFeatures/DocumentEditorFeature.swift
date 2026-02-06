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
		id: UUID = UUID(),
		fileURL: URL,
		cameraTransform: [Float]? = nil,
		cameraTransformRequestID: UUID? = nil,
		frameRequestID: UUID? = nil,
		reloadTrigger: UUID? = nil
	) {
        self.id = id
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
	@Dependency(\.date.now) var now
	@Dependency(\.uuid) var uuid
	@Dependency(\.workspacePersistenceClient) var workspacePersistenceClient
    
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
				let workspacePersistenceClient = self.workspacePersistenceClient
				return .run { send in
					if let restored = workspacePersistenceClient.loadWorkspaceRestore(documentURL) {
						await send(.workspaceRestored(restored))
					}
					if let gridVisible = workspacePersistenceClient.loadGridVisibility(documentURL) {
						await send(.gridVisibilityLoaded(gridVisible))
					}
				}

			case let .workspaceRestored(restored):
				state.openScenes = IdentifiedArray(
						uniqueElements: restored.openSceneURLs.map { url in
							SceneTab(
								id: uuid(),
								fileURL: url,
								cameraTransform: restored.cameraTransforms[url],
								cameraTransformRequestID: restored.cameraTransforms[url] == nil ? nil : uuid()
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
				let workspacePersistenceClient = self.workspacePersistenceClient
				return .merge(
					loadCameraHistoryEffect(
						documentURL: documentURL,
						sceneURL: selectedURL,
						workspacePersistenceClient: workspacePersistenceClient
					),
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
				let workspacePersistenceClient = self.workspacePersistenceClient
				if let documentURL = state.projectBrowser.documentURL,
				   let selectedURL = selectedSceneURL(state: state) {
					return .merge(
						updateUserDataEffect(
							state: state,
							workspacePersistenceClient: workspacePersistenceClient
						),
						loadCameraHistoryEffect(
							documentURL: documentURL,
							sceneURL: selectedURL,
							workspacePersistenceClient: workspacePersistenceClient
						),
						.send(.sceneNavigator(.sceneURLChanged(selectedURL))),
						.send(.inspector(.sceneURLChanged(selectedURL))),
						.send(.inspector(.selectionChanged(nil)))
					)
				}
				state.cameraHistory = []
				return .merge(
					updateUserDataEffect(
						state: state,
						workspacePersistenceClient: workspacePersistenceClient
					),
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
				let workspacePersistenceClient = self.workspacePersistenceClient
				if let existing = state.openScenes.first(where: { $0.fileURL == normalizedURL }) {
					print("[DocumentEditorFeature] Scene already open, switching to tab")
					state.selectedTab = .scene(id: existing.id)
				if let documentURL = state.projectBrowser.documentURL {
					return .merge(
						updateUserDataEffect(
							state: state,
							workspacePersistenceClient: workspacePersistenceClient
						),
						loadCameraHistoryEffect(
							documentURL: documentURL,
							sceneURL: normalizedURL,
							workspacePersistenceClient: workspacePersistenceClient
						),
						.send(.sceneNavigator(.sceneURLChanged(normalizedURL))),
						.send(.inspector(.sceneURLChanged(normalizedURL))),
						.send(.inspector(.selectionChanged(nil)))
					)
				}
				return .merge(
					updateUserDataEffect(
						state: state,
						workspacePersistenceClient: workspacePersistenceClient
					),
					.send(.sceneNavigator(.sceneURLChanged(normalizedURL))),
					.send(.inspector(.sceneURLChanged(normalizedURL))),
					.send(.inspector(.selectionChanged(nil)))
				)
			}
			
			// Open new scene
				let newTab = SceneTab(id: uuid(), fileURL: normalizedURL)
			print("[DocumentEditorFeature] Created new tab: \(newTab.id)")
			state.openScenes.append(newTab)
			state.selectedTab = .scene(id: newTab.id)
			print("[DocumentEditorFeature] Total open scenes: \(state.openScenes.count)")
			if let documentURL = state.projectBrowser.documentURL {
				return .merge(
					updateUserDataEffect(
						state: state,
						workspacePersistenceClient: workspacePersistenceClient
					),
					loadCameraHistoryEffect(
						documentURL: documentURL,
						sceneURL: normalizedURL,
						workspacePersistenceClient: workspacePersistenceClient
					),
					.send(.sceneNavigator(.sceneURLChanged(normalizedURL))),
					.send(.inspector(.sceneURLChanged(normalizedURL))),
					.send(.inspector(.selectionChanged(nil)))
				)
			}
			return .merge(
				updateUserDataEffect(
					state: state,
					workspacePersistenceClient: workspacePersistenceClient
				),
				.send(.sceneNavigator(.sceneURLChanged(normalizedURL))),
				.send(.inspector(.sceneURLChanged(normalizedURL))),
				.send(.inspector(.selectionChanged(nil)))
			)
                
			case let .sceneClosed(id):
				let workspacePersistenceClient = self.workspacePersistenceClient
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
						updateUserDataEffect(
							state: state,
							workspacePersistenceClient: workspacePersistenceClient
						),
						loadCameraHistoryEffect(
							documentURL: documentURL,
							sceneURL: selectedURL,
							workspacePersistenceClient: workspacePersistenceClient
						),
						.send(.sceneNavigator(.sceneURLChanged(selectedURL))),
						.send(.inspector(.sceneURLChanged(selectedURL))),
						.send(.inspector(.selectionChanged(nil)))
					)
				}
				state.cameraHistory = []
                return .merge(
					updateUserDataEffect(
						state: state,
						workspacePersistenceClient: workspacePersistenceClient
					),
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
				let workspacePersistenceClient = self.workspacePersistenceClient
					let entry = CameraHistoryItem(
						id: uuid(),
						date: now,
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
					try? workspacePersistenceClient.appendCameraHistory(
						documentURL,
						url,
						title,
						transform,
						entry.date
					)
				}

			case .frameSceneRequested, .frameSelectedRequested:
					guard case .scene(let id) = state.selectedTab,
					      var tab = state.openScenes[id: id] else {
						return .none
					}
					tab.frameRequestID = uuid()
					state.openScenes[id: id] = tab
					return .none

			case .toggleGridRequested:
				state.viewportShowGrid.toggle()
				guard let documentURL = state.projectBrowser.documentURL else {
					return .none
				}
				let isVisible = state.viewportShowGrid
				let workspacePersistenceClient = self.workspacePersistenceClient
				return .run { _ in
					try? workspacePersistenceClient.saveGridVisibility(documentURL, isVisible)
				}

			case let .cameraHistorySelected(id):
					guard case .scene(let selectedId) = state.selectedTab,
					      var tab = state.openScenes[id: selectedId],
					      let item = state.cameraHistory.first(where: { $0.id == id }) else {
						return .none
					}
					tab.cameraTransform = item.transform
					tab.cameraTransformRequestID = uuid()
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
					tab.reloadTrigger = uuid()
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

			case let .inspector(inspectorAction):
				// Keep viewport in sync after inspector-authored USD edits.
				if case .primTransformSaveSucceeded = inspectorAction,
				   case .scene(let tabID) = state.selectedTab,
				   var tab = state.openScenes[id: tabID] {
					tab.reloadTrigger = uuid()
					state.openScenes[id: tabID] = tab
					return .merge(
						.send(.projectBrowser(.sceneModified(tab.fileURL))),
						.send(.sceneNavigator(.refreshRequested))
					)
				}
				return .none
          
	            case let .sceneModified(tabID):
	            	if var tab = state.openScenes[id: tabID] {
	            		tab.reloadTrigger = uuid()
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

	public init(id: UUID = UUID(), date: Date, title: String, transform: [Float]) {
		self.id = id
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

private func updateUserDataEffect(
	state: DocumentEditorFeature.State,
	workspacePersistenceClient: WorkspacePersistenceClient
) -> Effect<DocumentEditorFeature.Action> {
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
		try? workspacePersistenceClient.saveOpenScenes(documentURL, openScenes, selectedURL)
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
	sceneURL: URL,
	workspacePersistenceClient: WorkspacePersistenceClient
) -> Effect<DocumentEditorFeature.Action> {
	.run { send in
		let items = workspacePersistenceClient.loadCameraHistory(documentURL, sceneURL)
		await send(.cameraHistoryLoaded(items))
	}
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

private enum CameraHistoryDebounceId: Hashable {
	case write
}
