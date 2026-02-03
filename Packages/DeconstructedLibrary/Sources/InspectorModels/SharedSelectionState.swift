import Foundation
import Sharing

// MARK: - Shared State Keys

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

// MARK: - Convenience Accessors

/// Access the writable shared selected scene URL
/// Usage: `@Shared(.selectedSceneURL) var selectedSceneURL`

/// Access the read-only shared selected scene URL  
/// Usage: `@SharedReader(.selectedSceneURL) var selectedSceneURL`

/// Access the writable shared selected prim path
/// Usage: `@Shared(.selectedPrimPath) var selectedPrimPath`

/// Access the read-only shared selected prim path
/// Usage: `@SharedReader(.selectedPrimPath) var selectedPrimPath`
