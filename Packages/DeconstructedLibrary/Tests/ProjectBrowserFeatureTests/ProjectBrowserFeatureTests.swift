import ComposableArchitecture
import Testing
@testable import ProjectBrowserFeature
@testable import ProjectBrowserModels

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
        }

        await store.receive(.assetsLoaded(mockItems)) {
            $0.isLoading = false
            $0.assetItems = mockItems
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
}
