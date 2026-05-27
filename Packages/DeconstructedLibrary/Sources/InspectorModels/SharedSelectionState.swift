import Foundation
import Sharing

// MARK: - Shared State Keys

public struct InspectorDisclosureState: Equatable, Sendable {
	public var primDataExpanded: Bool
	public var primAttributesExpanded: Bool
	public var materialBindingsExpanded: Bool
	public var materialPropertiesExpanded: Bool
	public var transformExpanded: Bool
	public var variantsExpanded: Bool
	public var referencesExpanded: Bool
	public var compositionExpanded: Bool
	public var componentsExpanded: Bool
	public var audioMixGroupsExpanded: Bool
	public var scenePlaybackExpanded: Bool
	public var layerDataExpanded: Bool
	public var materialsExpanded: Bool
	public var meshSortingGroupExpanded: Bool

	public init(
		primDataExpanded: Bool = true,
		primAttributesExpanded: Bool = true,
		materialBindingsExpanded: Bool = true,
		materialPropertiesExpanded: Bool = false,
		transformExpanded: Bool = true,
		variantsExpanded: Bool = true,
		referencesExpanded: Bool = true,
		compositionExpanded: Bool = false,
		componentsExpanded: Bool = true,
		audioMixGroupsExpanded: Bool = false,
		scenePlaybackExpanded: Bool = true,
		layerDataExpanded: Bool = true,
		materialsExpanded: Bool = true,
		meshSortingGroupExpanded: Bool = true
	) {
		self.primDataExpanded = primDataExpanded
		self.primAttributesExpanded = primAttributesExpanded
		self.materialBindingsExpanded = materialBindingsExpanded
		self.materialPropertiesExpanded = materialPropertiesExpanded
		self.transformExpanded = transformExpanded
		self.variantsExpanded = variantsExpanded
		self.referencesExpanded = referencesExpanded
		self.compositionExpanded = compositionExpanded
		self.componentsExpanded = componentsExpanded
		self.audioMixGroupsExpanded = audioMixGroupsExpanded
		self.scenePlaybackExpanded = scenePlaybackExpanded
		self.layerDataExpanded = layerDataExpanded
		self.materialsExpanded = materialsExpanded
		self.meshSortingGroupExpanded = meshSortingGroupExpanded
	}
}

/// Shared key for the currently selected scene URL across the entire app
public extension SharedKey where Self == InMemoryKey<URL?> {
	static var selectedSceneURL: Self {
		inMemory("selectedSceneURL")
	}
}

/// Shared key for the currently selected prim/node path in the scene graph
public extension SharedKey where Self == InMemoryKey<String?> {
	static var selectedPrimPath: Self {
		inMemory("selectedPrimPath")
	}
}

/// Shared key for inspector section disclosure state within the app session
public extension SharedKey where Self == InMemoryKey<InspectorDisclosureState>.Default {
	static var inspectorDisclosureState: Self {
		Self[.inMemory("inspectorDisclosureState"), default: InspectorDisclosureState()]
	}
}

// MARK: - Convenience Accessors

/// Access the writable shared selected scene URL
/// Usage: `@Shared(.selectedSceneURL) var selectedSceneURL`

/// Access the read-only shared selected scene URL  
/// Usage: `@SharedReader(.selectedSceneURL) var selectedSceneURL`

/// Access the writable shared selected prim path
/// Usage: `@Shared(.selectedPrimPath) var selectedPrimPath`

/// Access the read-only shared selected prim path
/// Usage: `@SharedReader(.selectedPrimPath) var selectedPrimPath`
