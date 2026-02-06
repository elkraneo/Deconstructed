import DeconstructedModels
import DeconstructedModels
import Foundation
import ProjectBrowserClients
import ProjectBrowserModels
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
		public var currentDirectoryId: AssetItem.ID? = nil

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
		public var isWatchingFiles: Bool = false
		public var watchedDirectoryURL: URL? = nil

		// Drag
		public var draggingItemIds: [AssetItem.ID] = []

		// Editing
		public var renamingItemId: AssetItem.ID? = nil

		// Thumbnail invalidation tracking - maps scene URL to a version UUID
		// When a scene is modified, its version changes, triggering thumbnail reload
		public var thumbnailVersions: [URL: UUID] = [:]

		public init() {}
	}

	public enum Action: Equatable, BindableAction {
		case binding(BindingAction<State>)

		// Lifecycle
		case onAppear
		case onDisappear
		case loadAssets(documentURL: URL)
		case assetsLoaded([AssetItem])
		case loadingFailed(String)

		// Selection
		case itemSelected(AssetItem.ID)
		case itemDoubleClicked(AssetItem.ID)
		case selectionCleared
		case setCurrentDirectory(AssetItem.ID?)

		// Drag
		case dragStarted([AssetItem.ID])
		case dragEnded

		// File Operations
		case importContentTapped
		case createFolderTapped
		case createSceneTapped
		case deleteSelectedTapped
		case renameSelectedTapped
		case renameItemCommitted(AssetItem.ID, String)
		case renameCancelled
		case duplicateSelectedTapped
		case moveSelectedTapped
		case moveItems([AssetItem.ID], to: AssetItem.ID?)

		// View Options
		case setViewMode(ViewMode)
		case setSortOrder(BrowserSortOrder)
		case toggleSortDirection

		// Filter
		case setFilterText(String)
		case setFilterFileType(AssetFileType?)

		// File watching
		case fileSystemEvent(FileWatcherClient.Event)
		case debouncedRefresh

		// Responses
		case fileOperationCompleted
		case fileOperationFailed(String)

		// Thumbnail invalidation
		case sceneModified(URL)
		case thumbnailInvalidated(URL)
	}

	@Dependency(\.assetDiscoveryClient) var assetDiscovery
	@Dependency(\.fileOperationsClient) var fileOperations
	@Dependency(\.fileWatcherClient) var fileWatcher
	@Dependency(\.thumbnailClient) var thumbnailClient
	@Dependency(\.projectBrowserDialogClient) var dialogClient
	@Dependency(\.projectDataIndexClient) var projectDataIndexClient
	@Dependency(\.continuousClock) var clock

	public init() {}

	public var body: some ReducerOf<Self> {
		BindingReducer()

		Reduce { state, action in
			switch action {
			case .binding:
				return .none

		case .onAppear:
			// Start file watching once we know the .rkassets root
			guard let rootURL = resolveRootDirectory(state: state),
			      state.watchedDirectoryURL != rootURL else {
				return .none
			}
			state.isWatchingFiles = true
			state.watchedDirectoryURL = rootURL
			let fileWatcher = self.fileWatcher
			return .run { send in
				for await event in fileWatcher.watch(rootURL) {
					await send(.fileSystemEvent(event))
				}
			}
			.cancellable(id: FileWatcherCancellationID.watcher, cancelInFlight: true)

		case .onDisappear:
			state.isWatchingFiles = false
			state.watchedDirectoryURL = nil
			return .cancel(id: FileWatcherCancellationID.watcher)

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
				if state.currentDirectoryId == nil {
					state.currentDirectoryId = items.first?.id
				}
				if let rootId = items.first?.id {
					state.expandedDirectories.insert(rootId)
				}
				guard let rootURL = resolveRootDirectory(state: state) else {
					if state.isWatchingFiles {
						state.isWatchingFiles = false
						state.watchedDirectoryURL = nil
						return .cancel(id: FileWatcherCancellationID.watcher)
					}
					return .none
				}
				guard state.watchedDirectoryURL != rootURL else {
					return .none
				}
				state.isWatchingFiles = true
				state.watchedDirectoryURL = rootURL
				let fileWatcher = self.fileWatcher
				return .run { send in
					for await event in fileWatcher.watch(rootURL) {
						await send(.fileSystemEvent(event))
					}
				}
				.cancellable(id: FileWatcherCancellationID.watcher, cancelInFlight: true)

			case let .loadingFailed(message):
				state.isLoading = false
				state.errorMessage = message
				return .none

			case let .itemSelected(id):
				state.selectedItems = [id]
				return .none

			case let .itemDoubleClicked(id):
				state.selectedItems = [id]
				return .none

			case .selectionCleared:
				state.selectedItems.removeAll()
				return .none

			case let .setCurrentDirectory(id):
				state.currentDirectoryId = id
				return .none

			case let .dragStarted(ids):
				state.draggingItemIds = ids
				return .none

			case .dragEnded:
				state.draggingItemIds = []
				return .none

			case .importContentTapped:
				guard let destination = resolveTargetDirectory(state: state) else {
					state.errorMessage = "Could not determine destination folder."
					return .none
				}
				let fileOperations = self.fileOperations
				let dialogClient = self.dialogClient
				return .run { send in
					let urls = await dialogClient.selectImportContentURLs()

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
					_ = try await fileOperations.createFolder(
						destination,
						DeconstructedConstants.FileName.newFolder
					)
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
			let documentURL = state.documentURL
			let fileOperations = self.fileOperations
			let projectDataIndexClient = self.projectDataIndexClient
			return .run { send in
				do {
					let sceneURL = try await fileOperations.createScene(
						destination,
						DeconstructedConstants.FileName.untitledScene
					)
					if let documentURL {
						try? projectDataIndexClient.registerNewScene(documentURL, sceneURL)
					}
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
				let documentURL = state.documentURL
				let itemURL = item.url
				let fileOperations = self.fileOperations
				let projectDataIndexClient = self.projectDataIndexClient
				return .run { send in
					do {
						let newURL = try await fileOperations.rename(itemURL, trimmed)
						if let documentURL {
							try projectDataIndexClient.registerMove(documentURL, itemURL, newURL)
						}
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

			case .moveSelectedTapped:
				guard let rootURL = resolveRootDirectory(state: state) else {
					state.errorMessage = "Could not resolve project root."
					return .none
				}
				let itemURLs = state.selectedItems.compactMap { id in
					findItem(in: state.assetItems, id: id)?.url
				}
				guard !itemURLs.isEmpty else {
					return .none
				}
				let documentURL = state.documentURL
				let fileOperations = self.fileOperations
				let dialogClient = self.dialogClient
				let projectDataIndexClient = self.projectDataIndexClient
				return .run { send in
					let destination = await dialogClient.selectMoveDestination(rootURL)

					guard let destination else { return }
					guard destination.path.hasPrefix(rootURL.path) else {
						await send(.fileOperationFailed("Destination must be inside the project."))
						return
					}

					do {
						let moved = try await fileOperations.move(itemURLs, destination)
						if let documentURL {
							for (from, to) in moved {
								try projectDataIndexClient.registerMove(documentURL, from, to)
							}
						}
						await send(.fileOperationCompleted)
					} catch {
						await send(.fileOperationFailed(error.localizedDescription))
					}
				}

			case let .moveItems(itemIDs, destinationID):
				guard let destinationID,
				      let destinationItem = findItem(in: state.assetItems, id: destinationID),
				      destinationItem.isDirectory else {
					return .none
				}
				// Don't move an item into itself
				let safeIDs = itemIDs.filter { $0 != destinationID }
				guard !safeIDs.isEmpty else { return .none }
				let itemURLs = safeIDs.compactMap { id in
					findItem(in: state.assetItems, id: id)?.url
				}
				guard !itemURLs.isEmpty else {
					return .none
				}
				let destinationURL = destinationItem.url
				let documentURL = state.documentURL
				let fileOperations = self.fileOperations
				let projectDataIndexClient = self.projectDataIndexClient
				return .run { send in
					do {
						let moved = try await fileOperations.move(itemURLs, destinationURL)
						if let documentURL {
							for (from, to) in moved {
								try projectDataIndexClient.registerMove(documentURL, from, to)
							}
						}
						await send(.fileOperationCompleted)
					} catch {
						await send(.fileOperationFailed(error.localizedDescription))
					}
				}

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

		case let .fileSystemEvent(event):
			guard let rootURL = resolveRootDirectory(state: state),
			      let eventURL = eventURL(event),
			      isDescendant(eventURL, of: rootURL) else {
				return .none
			}
			// Debounce file system events to prevent excessive reloads
			let clock = self.clock
			return .run { send in
				try await clock.sleep(for: .milliseconds(300))
				await send(.debouncedRefresh)
			}
			.cancellable(id: FileWatcherCancellationID.debounce, cancelInFlight: true)

		case .debouncedRefresh:
			// Actually perform the refresh after debouncing
			guard let documentURL = state.documentURL else {
				return .none
			}
			return .run { send in
				await send(.loadAssets(documentURL: documentURL))
			}

		case let .sceneModified(url):
			// Increment thumbnail version to trigger reload
			state.thumbnailVersions[url] = UUID()
			// Invalidate the cache
			let thumbnailClient = self.thumbnailClient
			return .run { _ in
				await thumbnailClient.invalidate(url)
			}

		case let .thumbnailInvalidated(url):
			// Thumbnail has been invalidated, version already updated in sceneModified
			// This action can be used for any post-invalidation logic if needed
			print("[ProjectBrowserFeature] Thumbnail invalidated for: \(url.lastPathComponent)")
			return .none
		}
		}
	}
}

// MARK: - Effect Cancellation ID
private enum FileWatcherCancellationID: Hashable {
	case watcher
	case debounce
}

private func findItem(in items: [AssetItem], id: AssetItem.ID) -> AssetItem? {
	AssetItem.find(in: items, id: id)
}

private func resolveTargetDirectory(state: ProjectBrowserFeature.State) -> URL? {
	if let selectedId = state.selectedItems.first,
	   let item = findItem(in: state.assetItems, id: selectedId) {
		return item.isDirectory ? item.url : item.url.deletingLastPathComponent()
	}

	if let currentId = state.currentDirectoryId,
	   let current = findItem(in: state.assetItems, id: currentId),
	   current.isDirectory {
		return current.url
	}

	if let rkassetsRoot = state.assetItems.first(where: { $0.url.isRKAssets }) {
		return rkassetsRoot.url
	}

	return nil
}

private func resolveRootDirectory(state: ProjectBrowserFeature.State) -> URL? {
	if let rkassetsRoot = state.assetItems.first(where: { $0.url.isRKAssets }) {
		return rkassetsRoot.url
	}
	return nil
}

private func eventURL(_ event: FileWatcherClient.Event) -> URL? {
	switch event {
	case let .created(url):
		return url
	case let .modified(url):
		return url
	case let .deleted(url):
		return url
	case let .renamed(_, to):
		return to
	}
}

private func isDescendant(_ url: URL, of root: URL) -> Bool {
	let rootPath = root.standardizedFileURL.path
	let urlPath = url.standardizedFileURL.path
	return urlPath == rootPath || urlPath.hasPrefix(rootPath + "/")
}
