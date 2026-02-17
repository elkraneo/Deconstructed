import ComposableArchitecture
import Testing
@testable import InspectorFeature
import USDInterfaces

@MainActor
struct InspectorFeatureAudioLibraryTests {
	@Test
	func parseAudioLibraryResources_extractsKeysAndValuesFromResourcesDescendant() {
		let descendants = [
			ComponentDescendantAttributes(
				primPath: "/Root/Entity/components/AudioLibrary/resources",
				displayName: "resources",
				authoredAttributes: [
					.init(name: "token[] keys", value: "[\"1bells.wav\", \"2bells.wav\"]"),
					.init(
						name: "rel values",
						value: "[</Root/Audio/1bells>, </Root/Audio/2bells>]"
					),
				],
			)
		]

		let resources = testAudioLibraryResources(from: descendants)

		#expect(resources.count == 2)
		#expect(resources[0] == .init(key: "1bells.wav", valueTarget: "/Root/Audio/1bells"))
		#expect(resources[1] == .init(key: "2bells.wav", valueTarget: "/Root/Audio/2bells"))
	}

	@Test
	func parseAudioLibraryResources_returnsEmptyWhenNoKeysArePresent() {
		let descendants = [
			ComponentDescendantAttributes(
				primPath: "/Root/Entity/components/AudioLibrary/resources",
				displayName: "resources",
				authoredAttributes: [
					.init(name: "rel values", value: "[</Root/Audio/1bells>]"),
				],
			)
		]

		let resources = testAudioLibraryResources(from: descendants)
		#expect(resources.isEmpty)
	}

	@Test
	func reducer_synthesizesResourcesDescendantForAudioLibraryWhenMissing() async {
		let componentPath = "/Root/Entity/components/AudioLibrary"
		let authored: [USDPrimAttributes.AuthoredAttribute] = [
			.init(name: "token info:id", value: "\"RealityKit.AudioLibrary\""),
			.init(name: "token[] keys", value: "[\"1bells.wav\"]"),
			.init(name: "rel values", value: "[</Root/Entity/components/AudioLibrary/1bells>]"),
		]

		let store = TestStore(initialState: InspectorFeature.State()) {
			InspectorFeature()
		}

		await store.send(.componentAuthoredAttributesLoaded([componentPath: authored])) {
			$0.componentAuthoredAttributesByPath[componentPath] = authored
			$0.componentDescendantAttributesByPath[componentPath] = [
				.init(
					primPath: "\(componentPath)/resources",
					displayName: "resources",
					authoredAttributes: [
						.init(name: "keys", value: "[\"1bells.wav\"]"),
						.init(name: "values", value: "[</Root/Entity/components/AudioLibrary/1bells>]"),
					],
				)
			]
		}
	}
}
