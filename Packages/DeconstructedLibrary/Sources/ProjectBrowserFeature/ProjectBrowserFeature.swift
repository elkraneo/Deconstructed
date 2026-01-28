import Foundation
import AppKit
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
		public var documentURL: URL? = nil

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
		case importContentTapped
        case createFolderTapped
		case createSceneTapped
        case deleteSelectedTapped
        case renameSelectedTapped
		case renameItemCommitted(AssetItem.ID, String)
		case renameCancelled
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
				state.documentURL = documentURL
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

			case .importContentTapped:
				guard let destination = resolveTargetDirectory(state: state) else {
					state.errorMessage = "Could not determine destination folder."
					return .none
				}
				let fileOperations = self.fileOperations
				return .run { send in
					let urls = await MainActor.run { () -> [URL] in
						let panel = NSOpenPanel()
						panel.canChooseFiles = true
						panel.canChooseDirectories = true
						panel.allowsMultipleSelection = true
						panel.title = "Import Content"
						panel.prompt = "Import"
						return panel.runModal() == .OK ? panel.urls : []
					}

					guard !urls.isEmpty else { return }

					do {
						for url in urls {
							_ = try await fileOperations.importFile(url, destination)
						}
						await send(.fileOperationCompleted)
					} catch {
						await send(.fileOperationFailed(error.localizedDescription))
					}
				}

            case .createFolderTapped:
				guard let destination = resolveTargetDirectory(state: state) else {
					state.errorMessage = "Could not determine destination folder."
					return .none
				}
				let fileOperations = self.fileOperations
				return .run { send in
					do {
						_ = try await fileOperations.createFolder(destination, "New Folder")
						await send(.fileOperationCompleted)
					} catch {
						await send(.fileOperationFailed(error.localizedDescription))
					}
				}

			case .createSceneTapped:
				guard let destination = resolveTargetDirectory(state: state) else {
					state.errorMessage = "Could not determine destination folder."
					return .none
				}
				let fileOperations = self.fileOperations
				return .run { send in
					do {
						_ = try await fileOperations.createScene(destination, "Untitled Scene")
						await send(.fileOperationCompleted)
					} catch {
						await send(.fileOperationFailed(error.localizedDescription))
					}
				}

            case .deleteSelectedTapped:
                return .none

            case .renameSelectedTapped:
				guard state.selectedItems.count == 1,
				      let id = state.selectedItems.first else {
					return .none
				}
				state.renamingItemId = id
				return .none

			case let .renameItemCommitted(id, newName):
				state.renamingItemId = nil
				let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
				guard !trimmed.isEmpty,
				      let item = findItem(in: state.assetItems, id: id),
				      trimmed != item.url.lastPathComponent else {
					return .none
				}
				let fileOperations = self.fileOperations
				return .run { send in
					do {
						_ = try await fileOperations.rename(item.url, trimmed)
						await send(.fileOperationCompleted)
					} catch {
						await send(.fileOperationFailed(error.localizedDescription))
					}
				}

			case .renameCancelled:
				state.renamingItemId = nil
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
				guard let documentURL = state.documentURL else {
					return .none
				}
				return .run { send in
					await send(.loadAssets(documentURL: documentURL))
				}

            case let .fileOperationFailed(message):
				state.errorMessage = message
                return .none
            }
        }
    }
}

private func findItem(in items: [AssetItem], id: AssetItem.ID) -> AssetItem? {
	for item in items {
		if item.id == id {
			return item
		}
		if let children = item.children,
		   let match = findItem(in: children, id: id) {
			return match
		}
	}
	return nil
}

private func resolveTargetDirectory(state: ProjectBrowserFeature.State) -> URL? {
	if let selectedId = state.selectedItems.first,
	   let item = findItem(in: state.assetItems, id: selectedId) {
		return item.isDirectory ? item.url : item.url.deletingLastPathComponent()
	}

	if let rkassetsRoot = state.assetItems.first(where: { $0.url.pathExtension == "rkassets" }) {
		return rkassetsRoot.url
	}

	return nil
}
