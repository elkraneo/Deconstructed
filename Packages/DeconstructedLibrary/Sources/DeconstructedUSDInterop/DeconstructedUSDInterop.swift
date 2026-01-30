import CxxStdlib
import Foundation
import OpenUSD

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
	public static func setDefaultPrim(url: URL, primPath: String) throws {
		let stage = try openStage(url)
		let prim = try resolvePrim(stage: stage, primPath: primPath)
		let didSet = stage.SetDefaultPrim(prim)
		guard didSet else {
			throw DeconstructedUSDInteropError.setDefaultPrimFailed(primPath)
		}
		try save(stage: stage, url: url)
	}

	public static func applySchema(url: URL, primPath: String, schema: SchemaSpec) throws {
		let stage = try openStage(url)
		let prim = try resolvePrim(stage: stage, primPath: primPath)
		let schemaToken = pxr.TfToken(std.string(schema.identifier))
		let applied: Bool
		switch schema.kind {
		case .api:
			applied = prim.ApplyAPI(schemaToken)
		case let .multipleApplyAPI(instanceName):
			let instanceToken = pxr.TfToken(std.string(instanceName))
			applied = prim.ApplyAPI(schemaToken, instanceToken)
		case .typed:
			prim.SetTypeName(schemaToken)
			applied = true
		}
		guard applied else {
			throw DeconstructedUSDInteropError.applySchemaFailed(schema: schema.identifier, primPath: primPath)
		}
		try save(stage: stage, url: url)
	}

	public static func editHierarchy(url: URL, edits: [EditOp]) throws {
		_ = url
		_ = edits
		// TODO: Implement hierarchy edits once EditOp is defined.
		throw DeconstructedUSDInteropError.notImplemented
	}

	private static func openStage(_ url: URL) throws -> pxr.UsdStage {
		let stageRef = pxr.UsdStage.Open(std.string(url.path))
		guard let stage = Overlay.DereferenceOrNil(stageRef) else {
			throw DeconstructedUSDInteropError.stageOpenFailed(url)
		}
		return stage
	}

	private static func resolvePrim(stage: pxr.UsdStage, primPath: String) throws -> pxr.UsdPrim {
		let path = pxr.SdfPath(std.string(primPath))
		let prim = stage.GetPrimAtPath(path)
		guard Bool(prim) else {
			throw DeconstructedUSDInteropError.primNotFound(primPath)
		}
		return prim
	}

	private static func save(stage: pxr.UsdStage, url: URL) throws {
		let rootLayerHandle = stage.GetRootLayer()
		guard let rootLayer = Overlay.DereferenceOrNil(rootLayerHandle) else {
			throw DeconstructedUSDInteropError.rootLayerMissing(url)
		}
		guard rootLayer.Save() else {
			throw DeconstructedUSDInteropError.saveFailed(url)
		}
	}
}
