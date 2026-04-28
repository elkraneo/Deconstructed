import ComposableArchitecture
import DeconstructedModels
import Foundation

/// Client for editing USD scene content (creating prims, etc.).
public struct SceneEditClient: Sendable {
	/// Creates a primitive shape in the scene.
	/// - Parameters:
	///   - url: The USD scene file URL.
	///   - parentPath: The parent prim path (e.g., "/Root").
	///   - primitiveType: The type of primitive to create.
	///   - name: Optional custom name.
	/// - Returns: The full path of the created prim.
	public var createPrimitive: @Sendable (
		_ url: URL,
		_ parentPath: String,
		_ primitiveType: USDPrimitiveType,
		_ name: String?
	) async throws -> String

	/// Creates a structural prim (Xform or Scope) in the scene.
	/// - Parameters:
	///   - url: The USD scene file URL.
	///   - parentPath: The parent prim path (e.g., "/Root").
	///   - structuralType: The type of structural prim to create.
	///   - name: Optional custom name.
	/// - Returns: The full path of the created prim.
	public var createStructural: @Sendable (
		_ url: URL,
		_ parentPath: String,
		_ structuralType: USDStructuralType,
		_ name: String?
	) async throws -> String

	public init(
		createPrimitive: @escaping @Sendable (URL, String, USDPrimitiveType, String?) async throws -> String,
		createStructural: @escaping @Sendable (URL, String, USDStructuralType, String?) async throws -> String
	) {
		self.createPrimitive = createPrimitive
		self.createStructural = createStructural
	}
}

private enum SceneEditClientKey: DependencyKey {
	static var liveValue: SceneEditClient {
		SceneEditClient(
			createPrimitive: { _, _, _, _ in
				throw SceneEditClientError.runtimeUnavailable
			},
			createStructural: { _, _, _, _ in
				throw SceneEditClientError.runtimeUnavailable
			}
		)
	}

	static var testValue: SceneEditClient {
		SceneEditClient(
			createPrimitive: { _, _, _, _ in "/" },
			createStructural: { _, _, _, _ in "/" }
		)
	}
}

public enum SceneEditClientError: Error, LocalizedError, Sendable {
	case runtimeUnavailable

	public var errorDescription: String? {
		switch self {
		case .runtimeUnavailable:
			return "OpenUSD scene editing runtime is not available."
		}
	}
}

public extension DependencyValues {
	var sceneEditClient: SceneEditClient {
		get { self[SceneEditClientKey.self] }
		set { self[SceneEditClientKey.self] = newValue }
	}
}
