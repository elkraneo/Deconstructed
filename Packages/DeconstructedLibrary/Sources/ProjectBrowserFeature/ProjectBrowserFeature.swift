import Foundation
import AppKit
import DeconstructedModels
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

		// Drag
		public var draggingItemIds: [AssetItem.ID] = []

		// Editing
		public var renamingItemId: AssetItem.ID? = nil

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

		// Responses
		case fileOperationCompleted
		case fileOperationFailed(String)
	}

	@Dependency(\.assetDiscoveryClient) var assetDiscovery
	@Dependency(\.fileOperationsClient) var fileOperations
	@Dependency(\.fileWatcherClient) var fileWatcher

	public init() {}

	public var body: some ReducerOf<Self> {
		BindingReducer()

		Reduce { state, action in
			switch action {
			case .binding:
				return .none

		case .onAppear:
			// Start file watching if document URL is available
			guard let documentURL = state.documentURL else {
				return .none
			}
			let parentURL = documentURL.deletingLastPathComponent()
			let fileWatcher = self.fileWatcher
			return .run { send in
				for await event in fileWatcher.watch(parentURL) {
					await send(.fileSystemEvent(event))
				}
			}
			.cancellable(id: FileWatcherCancellationID.watcher)

			case .onDisappear:
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
				let documentURL = state.documentURL
				let fileOperations = self.fileOperations
				return .run { send in
					do {
						let sceneURL = try await fileOperations.createScene(destination, "Untitled Scene")
						if let documentURL {
							try? updateProjectDataForNewScene(documentURL: documentURL, sceneURL: sceneURL)
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
				return .run { send in
					do {
						let newURL = try await fileOperations.rename(itemURL, trimmed)
						if let documentURL {
							try updateProjectDataForMove(documentURL: documentURL, from: itemURL, to: newURL)
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
				return .run { send in
					let destination = await MainActor.run { () -> URL? in
						let panel = NSOpenPanel()
						panel.canChooseFiles = false
						panel.canChooseDirectories = true
						panel.allowsMultipleSelection = false
						panel.directoryURL = rootURL
						panel.title = "Move To Folder"
						panel.prompt = "Move"
						return panel.runModal() == .OK ? panel.url : nil
					}

					guard let destination else { return }
					guard destination.path.hasPrefix(rootURL.path) else {
						await send(.fileOperationFailed("Destination must be inside the project."))
						return
					}

					do {
						let moved = try await fileOperations.move(itemURLs, destination)
						if let documentURL {
							for (from, to) in moved {
								try updateProjectDataForMove(documentURL: documentURL, from: from, to: to)
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
				return .run { send in
					do {
						let moved = try await fileOperations.move(itemURLs, destinationURL)
						if let documentURL {
							for (from, to) in moved {
								try updateProjectDataForMove(documentURL: documentURL, from: from, to: to)
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

			case .fileSystemEvent:
				// Auto-refresh assets when file system changes detected
				guard let documentURL = state.documentURL else {
					return .none
				}
				return .run { send in
					await send(.loadAssets(documentURL: documentURL))
				}
			}
		}
	}
}

// MARK: - Effect Cancellation ID
private enum FileWatcherCancellationID: Hashable { case watcher }

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

	if let rkassetsRoot = state.assetItems.first(where: { $0.url.pathExtension == "rkassets" }) {
		return rkassetsRoot.url
	}

	return nil
}

private func resolveRootDirectory(state: ProjectBrowserFeature.State) -> URL? {
	if let rkassetsRoot = state.assetItems.first(where: { $0.url.pathExtension == "rkassets" }) {
		return rkassetsRoot.url
	}
	return nil
}

private func updateProjectDataForNewScene(documentURL: URL, sceneURL: URL) throws {
	let projectDataURL = documentURL.appendingPathComponent("ProjectData/main.json")
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
}

private func updateProjectDataForMove(documentURL: URL, from: URL, to: URL) throws {
	let projectDataURL = documentURL.appendingPathComponent("ProjectData/main.json")
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
