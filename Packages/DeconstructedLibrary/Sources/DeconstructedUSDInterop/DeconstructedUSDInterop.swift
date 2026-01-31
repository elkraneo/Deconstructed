import Foundation
import USDInterfaces
import USDInterop
import USDInteropAdvanced

public enum DeconstructedUSDInteropError: Error, LocalizedError, Sendable {
	case stageOpenFailed(URL)
	case rootLayerMissing(URL)
	case saveFailed(URL)
	case primNotFound(String)
	case setDefaultPrimFailed(String)
	case applySchemaFailed(schema: String, primPath: String)
	case notImplemented

	public var errorDescription: String? {
		switch self {
		case let .stageOpenFailed(url):
			return "Failed to open USD stage at \(url.path)."
		case let .rootLayerMissing(url):
			return "USD stage at \(url.path) has no root layer."
		case let .saveFailed(url):
			return "Failed to save USD stage at \(url.path)."
		case let .primNotFound(path):
			return "No prim found at path \(path)."
		case let .setDefaultPrimFailed(path):
			return "Failed to set default prim at path \(path)."
		case let .applySchemaFailed(schema, primPath):
			return "Failed to apply schema \(schema) to prim \(primPath)."
		case .notImplemented:
			return "Operation is not implemented yet."
		}
	}
}

public struct SchemaSpec: Sendable, Hashable {
	public enum Kind: Sendable, Hashable {
		case api
		case multipleApplyAPI(instanceName: String)
		case typed
	}

	public var identifier: String
	public var kind: Kind

	public init(identifier: String, kind: Kind = .api) {
		self.identifier = identifier
		self.kind = kind
	}
}

public struct EditOp: Sendable, Hashable {
	public init() {}
}

public enum DeconstructedUSDInterop {
	private static let advancedClient = USDAdvancedClient()

	public static func setDefaultPrim(url: URL, primPath: String) throws {
		do {
			try advancedClient.setDefaultPrim(url: url, primPath: primPath)
		} catch {
			throw mapAdvancedError(error, url: url, primPath: primPath, schema: nil)
		}
	}

	public static func applySchema(url: URL, primPath: String, schema: SchemaSpec) throws {
		let spec = USDSchemaSpec(identifier: schema.identifier, kind: mapSchemaKind(schema.kind))
		do {
			try advancedClient.applySchema(url: url, primPath: primPath, schema: spec)
		} catch {
			throw mapAdvancedError(error, url: url, primPath: primPath, schema: schema.identifier)
		}
	}

	public static func editHierarchy(url: URL, edits: [EditOp]) throws {
		_ = url
		_ = edits
		// TODO: Implement hierarchy edits once EditOp is defined.
		throw DeconstructedUSDInteropError.notImplemented
	}

	/// Compute scene bounds by iterating mesh points.
	/// Returns (min, max, center, maxExtent) for camera framing.
	public static func getSceneBounds(url: URL) throws -> (
		min: SIMD3<Float>, max: SIMD3<Float>, center: SIMD3<Float>, maxExtent: Float
	) {
		if let bounds = USDInteropStage.sceneBounds(url: url) {
			return (min: bounds.min, max: bounds.max, center: bounds.center, maxExtent: bounds.maxExtent)
		}
		return (min: .zero, max: .zero, center: .zero, maxExtent: 0)
	}

	private static func mapSchemaKind(_ kind: SchemaSpec.Kind) -> USDSchemaSpec.Kind {
		switch kind {
		case .api:
			return .api
		case let .multipleApplyAPI(instanceName):
			return .multipleApplyAPI(instanceName: instanceName)
		case .typed:
			return .typed
		}
	}

	private static func mapAdvancedError(
		_ error: Error,
		url: URL,
		primPath: String,
		schema: String?
	) -> Error {
		if let advancedError = error as? USDAdvancedError {
			switch advancedError {
			case .stageOpenFailed:
				return DeconstructedUSDInteropError.stageOpenFailed(url)
			case .primNotFound:
				return DeconstructedUSDInteropError.primNotFound(primPath)
			case .rootLayerMissing:
				return DeconstructedUSDInteropError.rootLayerMissing(url)
			case .saveFailed:
				return DeconstructedUSDInteropError.saveFailed(url)
			case .applySchemaFailed:
				return DeconstructedUSDInteropError.applySchemaFailed(
					schema: schema ?? "Unknown",
					primPath: primPath
				)
			case .invalidScope, .variantSetNotFound:
				return error
			}
		}
		return error
	}
}
