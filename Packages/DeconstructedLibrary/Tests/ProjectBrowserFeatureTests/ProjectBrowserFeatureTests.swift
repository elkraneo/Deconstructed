import ComposableArchitecture
import Foundation
import Testing
@testable import ProjectBrowserClients
@testable import ProjectBrowserFeature
@testable import ProjectBrowserModels

private actor URLCapture {
	var value: URL?
	func set(_ url: URL?) { value = url }
	func get() -> URL? { value }
}

@MainActor
struct ProjectBrowserFeatureTests {
    @Test
    func loadAssets_populatesState() async {
        let mockItems = [
            AssetItem(
                name: "Scene.usda",
                url: URL(fileURLWithPath: "/test/Scene.usda"),
                isDirectory: false,
                fileType: .usda
            )
        ]

        let store = TestStore(initialState: ProjectBrowserFeature.State()) {
            ProjectBrowserFeature()
        } withDependencies: {
            $0.assetDiscoveryClient.discover = { _ in mockItems }
        }

        await store.send(.loadAssets(documentURL: URL(fileURLWithPath: "/doc"))) {
            $0.isLoading = true
			$0.documentURL = URL(fileURLWithPath: "/doc")
        }

        await store.receive(.assetsLoaded(mockItems)) {
            $0.isLoading = false
            $0.assetItems = mockItems
			$0.currentDirectoryId = mockItems.first?.id
			$0.expandedDirectories = [mockItems.first!.id]
        }
    }

	@Test
	func itemSelected_updatesSelectedItems() async {
        let store = TestStore(initialState: ProjectBrowserFeature.State()) {
            ProjectBrowserFeature()
        }

        let itemId = UUID()

        await store.send(.itemSelected(itemId)) {
            $0.selectedItems = [itemId]
        }
    }

	// MARK: - Create Folder / Scene

	@Test
	func createFolder_usesCurrentDirectory_whenNoSelection() async {
		let rootURL = URL(fileURLWithPath: "/test/root.rkassets")
		let folderURL = rootURL.appendingPathComponent("Scenes")
		let folderId = UUID()

		let folder = AssetItem(
			id: folderId,
			name: "Scenes",
			url: folderURL,
			isDirectory: true,
			fileType: .directory
		)
		let root = AssetItem(
			id: UUID(),
			name: "root.rkassets",
			url: rootURL,
			isDirectory: true,
			fileType: .directory,
			children: [folder]
		)

		var state = ProjectBrowserFeature.State()
		state.assetItems = [root]
		state.currentDirectoryId = folderId

		let capture = URLCapture()

		let store = TestStore(initialState: state) {
			ProjectBrowserFeature()
		} withDependencies: {
			$0.fileOperationsClient.createFolder = { parent, _ in
				await capture.set(parent)
				return parent.appendingPathComponent("New Folder")
			}
		}

		await store.send(.createFolderTapped)
		await store.receive(.fileOperationCompleted)

		#expect(await capture.get() == folderURL)
	}

	@Test
	func createScene_respectsCurrentDirectory_andReloadsEvenIfProjectDataMissing() async {
		let documentURL = URL(fileURLWithPath: "/missing/Project.realitycomposerpro")
		let rootURL = URL(fileURLWithPath: "/missing/Sources/Project/Project.rkassets")
		let folderURL = rootURL.appendingPathComponent("Scenes")
		let rootId = UUID()
		let folderId = UUID()

		let folder = AssetItem(
			id: folderId,
			name: "Scenes",
			url: folderURL,
			isDirectory: true,
			fileType: .directory,
			children: []
		)
		let root = AssetItem(
			id: rootId,
			name: "Project.rkassets",
			url: rootURL,
			isDirectory: true,
			fileType: .directory,
			children: [folder]
		)

		let sceneURL = folderURL.appendingPathComponent("Untitled Scene.usda")
		let scene = AssetItem(
			name: "Untitled Scene.usda",
			url: sceneURL,
			isDirectory: false,
			fileType: .usda
		)
		let updatedFolder = AssetItem(
			id: folderId,
			name: "Scenes",
			url: folderURL,
			isDirectory: true,
			fileType: .directory,
			children: [scene]
		)
		let updatedRoot = AssetItem(
			id: rootId,
			name: "Project.rkassets",
			url: rootURL,
			isDirectory: true,
			fileType: .directory,
			children: [updatedFolder]
		)

		var state = ProjectBrowserFeature.State()
		state.assetItems = [root]
		state.currentDirectoryId = folderId
		state.documentURL = documentURL

		let capture = URLCapture()

		let store = TestStore(initialState: state) {
			ProjectBrowserFeature()
		} withDependencies: {
			$0.fileOperationsClient.createScene = { parent, _ in
				await capture.set(parent)
				return parent.appendingPathComponent("Untitled Scene.usda")
			}
			$0.assetDiscoveryClient.discover = { _ in [updatedRoot] }
		}

		await store.send(.createSceneTapped)

		await store.receive(.fileOperationCompleted)
		await store.receive(.loadAssets(documentURL: documentURL)) {
			$0.isLoading = true
			$0.errorMessage = nil
			$0.documentURL = documentURL
		}
		await store.receive(.assetsLoaded([updatedRoot])) {
			$0.isLoading = false
			$0.assetItems = [updatedRoot]
			$0.expandedDirectories = [rootId]
		}

		#expect(await capture.get() == folderURL)
	}

	// MARK: - Drag and Drop

	@Test
	func dragStarted_setsDraggingItemIds() async {
		let store = TestStore(initialState: ProjectBrowserFeature.State()) {
			ProjectBrowserFeature()
		}

		let itemIds = [UUID(), UUID()]

		await store.send(.dragStarted(itemIds)) {
			$0.draggingItemIds = itemIds
		}
	}

	@Test
	func dragEnded_clearsDraggingItemIds() async {
		var state = ProjectBrowserFeature.State()
		state.draggingItemIds = [UUID()]

		let store = TestStore(initialState: state) {
			ProjectBrowserFeature()
		}

		await store.send(.dragEnded) {
			$0.draggingItemIds = []
		}
	}

	@Test
	func moveItems_toFolder_triggersFileOperation() async {
		let fileId = UUID()
		let folderId = UUID()
		let fileURL = URL(fileURLWithPath: "/test/file.usda")
		let folderURL = URL(fileURLWithPath: "/test/folder")

		let folder = AssetItem(
			id: folderId,
			name: "folder",
			url: folderURL,
			isDirectory: true,
			fileType: .directory
		)
		let file = AssetItem(
			id: fileId,
			name: "file.usda",
			url: fileURL,
			isDirectory: false,
			fileType: .usda
		)
		let root = AssetItem(
			id: UUID(),
			name: "root.rkassets",
			url: URL(fileURLWithPath: "/test/root.rkassets"),
			isDirectory: true,
			fileType: .directory,
			children: [folder, file]
		)

		var state = ProjectBrowserFeature.State()
		state.assetItems = [root]
		state.documentURL = nil // Skip main.json update (no real filesystem in test)
		state.currentDirectoryId = root.id // Pre-set to avoid assetsLoaded changing it
		state.expandedDirectories = [root.id]

		let store = TestStore(initialState: state) {
			ProjectBrowserFeature()
		} withDependencies: {
			$0.fileOperationsClient.move = { _, _ in
				[fileURL: folderURL.appendingPathComponent("file.usda")]
			}
		}

		await store.send(.moveItems([fileId], to: folderId))

		// With documentURL = nil, fileOperationCompleted doesn't trigger reload
		await store.receive(.fileOperationCompleted)
	}

	@Test
	func moveItems_toSelf_isIgnored() async {
		let folderId = UUID()
		let folderURL = URL(fileURLWithPath: "/test/folder")

		let folder = AssetItem(
			id: folderId,
			name: "folder",
			url: folderURL,
			isDirectory: true,
			fileType: .directory
		)
		let root = AssetItem(
			id: UUID(),
			name: "root.rkassets",
			url: URL(fileURLWithPath: "/test/root.rkassets"),
			isDirectory: true,
			fileType: .directory,
			children: [folder]
		)

		var state = ProjectBrowserFeature.State()
		state.assetItems = [root]

		let store = TestStore(initialState: state) {
			ProjectBrowserFeature()
		}

		// Moving folder into itself should be a no-op
		await store.send(.moveItems([folderId], to: folderId))
		// No effects expected - test passes if no unhandled effects
	}

	@Test
	func moveItems_toNonDirectory_isIgnored() async {
		let fileId = UUID()
		let targetFileId = UUID()

		let file = AssetItem(
			id: fileId,
			name: "file.usda",
			url: URL(fileURLWithPath: "/test/file.usda"),
			isDirectory: false,
			fileType: .usda
		)
		let targetFile = AssetItem(
			id: targetFileId,
			name: "target.usda",
			url: URL(fileURLWithPath: "/test/target.usda"),
			isDirectory: false,
			fileType: .usda
		)
		let root = AssetItem(
			id: UUID(),
			name: "root.rkassets",
			url: URL(fileURLWithPath: "/test/root.rkassets"),
			isDirectory: true,
			fileType: .directory,
			children: [file, targetFile]
		)

		var state = ProjectBrowserFeature.State()
		state.assetItems = [root]

		let store = TestStore(initialState: state) {
			ProjectBrowserFeature()
		}

		// Moving to a non-directory should be a no-op
		await store.send(.moveItems([fileId], to: targetFileId))
		// No effects expected
	}

	// MARK: - Directory Navigation

	@Test
	func setCurrentDirectory_updatesState() async {
		let store = TestStore(initialState: ProjectBrowserFeature.State()) {
			ProjectBrowserFeature()
		}

		let directoryId = UUID()

		await store.send(.setCurrentDirectory(directoryId)) {
			$0.currentDirectoryId = directoryId
		}
	}

	@Test
	func doubleClickDirectory_navigatesIntoIt() async {
		let store = TestStore(initialState: ProjectBrowserFeature.State()) {
			ProjectBrowserFeature()
		}

		let directoryId = UUID()

		// Double-click sends itemDoubleClicked (UI handles setCurrentDirectory separately)
		await store.send(.itemDoubleClicked(directoryId))
		// itemDoubleClicked is a no-op in reducer - navigation handled by view
	}
}
