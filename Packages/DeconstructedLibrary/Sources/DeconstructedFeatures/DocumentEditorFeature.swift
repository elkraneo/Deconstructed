import ComposableArchitecture
import Foundation
import ProjectBrowserFeature
import ViewportModels

/// Represents an open scene tab with its viewport state
public struct SceneTab: Equatable, Identifiable {
    public let id: UUID
    public let fileURL: URL
    public let displayName: String
    
    public init(fileURL: URL) {
        self.id = UUID()
        let normalized = normalizedSceneURL(fileURL)
        self.fileURL = normalized
        self.displayName = normalized.lastPathComponent
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
        case tabSelected(EditorTab?)
        case bottomTabSelected(BottomTab)
        case sceneOpened(URL)
        case sceneClosed(UUID)
        case projectBrowser(ProjectBrowserFeature.Action)
    }
    
    public init() {}
    
    public var body: some ReducerOf<Self> {
        Scope(state: \.projectBrowser, action: \.projectBrowser) {
            ProjectBrowserFeature()
        }
        
        Reduce { state, action in
            switch action {
            case let .tabSelected(tab):
                state.selectedTab = tab
                return .none
                
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
					return .none
				}
				
				// Open new scene
				let newTab = SceneTab(fileURL: normalizedURL)
				print("[DocumentEditorFeature] Created new tab: \(newTab.id)")
				state.openScenes.append(newTab)
				state.selectedTab = .scene(id: newTab.id)
				print("[DocumentEditorFeature] Total open scenes: \(state.openScenes.count)")
				return .none
                
            case let .sceneClosed(id):
                state.openScenes.remove(id: id)
                if case .scene(let selectedId) = state.selectedTab, selectedId == id {
                    if let next = state.openScenes.first {
                        state.selectedTab = .scene(id: next.id)
                    } else {
                        state.selectedTab = nil
                    }
                }
                return .none
                
            case .projectBrowser:
                return .none
            }
        }
    }
}

private func normalizedSceneURL(_ url: URL) -> URL {
    URL(fileURLWithPath: url.path).standardizedFileURL
}
