import Foundation
import ProjectBrowserModels
import ProjectBrowserClients
import ComposableArchitecture

@Reducer
public struct ProjectBrowserFeature {
    @ObservableState
    public struct State: Equatable {
        // Content
        public var assetItems: [AssetItem] = []
        public var selectedItems: Set<AssetItem.ID> = []
        public var expandedDirectories: Set<AssetItem.ID> = []

        // View Options
        public var viewMode: ViewMode = .icons
        public var iconSize: Double = 80
        public var sortOrder: BrowserSortOrder = .name
        public var sortAscending: Bool = true
        public var filterText: String = ""
        public var filterFileType: AssetFileType? = nil

        // State
        public var isLoading: Bool = false
        public var errorMessage: String? = nil

        // Editing
        public var renamingItemId: AssetItem.ID? = nil

        public init() {}
    }

    public enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)

        // Lifecycle
        case onAppear
        case loadAssets(documentURL: URL)
        case assetsLoaded([AssetItem])
        case loadingFailed(String)

        // Selection
        case itemSelected(AssetItem.ID)
        case itemDoubleClicked(AssetItem.ID)
        case selectionCleared

        // File Operations
        case createFolderTapped
        case deleteSelectedTapped
        case renameSelectedTapped
        case duplicateSelectedTapped
        case moveItems([AssetItem.ID], to: AssetItem.ID?)

        // View Options
        case setViewMode(ViewMode)
        case setSortOrder(BrowserSortOrder)
        case toggleSortDirection

        // Filter
        case setFilterText(String)
        case setFilterFileType(AssetFileType?)

        // Responses
        case fileOperationCompleted
        case fileOperationFailed(String)
    }

    @Dependency(\.assetDiscoveryClient) var assetDiscovery
    @Dependency(\.fileOperationsClient) var fileOperations

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .onAppear:
                return .none

            case let .loadAssets(documentURL):
                state.isLoading = true
                state.errorMessage = nil
                let assetDiscovery = self.assetDiscovery
                return .run { send in
                    do {
                        let items = try await assetDiscovery.discover(documentURL)
                        await send(.assetsLoaded(items))
                    } catch {
                        await send(.loadingFailed(error.localizedDescription))
                    }
                }

            case let .assetsLoaded(items):
                state.isLoading = false
                state.assetItems = items
                return .none

            case let .loadingFailed(message):
                state.isLoading = false
                state.errorMessage = message
                return .none

            case let .itemSelected(id):
                state.selectedItems = [id]
                return .none

            case .itemDoubleClicked:
                return .none

            case .selectionCleared:
                state.selectedItems.removeAll()
                return .none

            case .createFolderTapped:
                return .none

            case .deleteSelectedTapped:
                return .none

            case .renameSelectedTapped:
                return .none

            case .duplicateSelectedTapped:
                return .none

            case .moveItems:
                return .none

            case let .setViewMode(mode):
                state.viewMode = mode
                return .none

            case let .setSortOrder(order):
                state.sortOrder = order
                return .none

            case .toggleSortDirection:
                state.sortAscending.toggle()
                return .none

            case let .setFilterText(text):
                state.filterText = text
                return .none

            case .setFilterFileType:
                return .none

            case .fileOperationCompleted:
                return .none

            case .fileOperationFailed:
                return .none
            }
        }
    }
}
