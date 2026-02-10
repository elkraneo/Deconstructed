import Foundation
import USDInterfaces
import USDInterop
import USDInteropAdvanced
import USDInteropAdvancedCore

public enum DeconstructedUSDInteropError: Error, LocalizedError, Sendable {
	case stageOpenFailed(URL)
	case rootLayerMissing(URL)
	case saveFailed(URL)
	case primNotFound(String)
	case setDefaultPrimFailed(String)
	case setMetersPerUnitFailed(Double)
	case setUpAxisFailed(String)
	case applySchemaFailed(schema: String, primPath: String)
	case createPrimFailed(path: String, typeName: String)
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
		case let .setMetersPerUnitFailed(value):
			return "Failed to set metersPerUnit to \(value)."
		case let .setUpAxisFailed(axis):
			return "Failed to set upAxis to \(axis)."
		case let .applySchemaFailed(schema, primPath):
			return "Failed to apply schema \(schema) to prim \(primPath)."
		case let .createPrimFailed(path, typeName):
			return "Failed to create prim at \(path) with type \(typeName)."
		case .notImplemented:
			return "Operation is not implemented yet."
		}
	}
}

/// Primitive shape types that can be inserted into a USD scene.
public enum USDPrimitiveType: String, CaseIterable, Sendable {
	case capsule = "Capsule"
	case cone = "Cone"
	case cube = "Cube"
	case cylinder = "Cylinder"
	case sphere = "Sphere"

	/// The USD type name for this primitive.
	public var typeName: String { rawValue }

	/// A human-readable display name.
	public var displayName: String { rawValue }

	/// The SF Symbol icon name for this primitive.
	public var iconName: String {
		switch self {
		case .capsule: return "capsule"
		case .cone: return "cone"
		case .cube: return "cube"
		case .cylinder: return "cylinder"
		case .sphere: return "circle"
		}
	}
}

/// Structural prim types (grouping containers).
public enum USDStructuralType: String, CaseIterable, Sendable {
	case xform = "Xform"
	case scope = "Scope"

	/// The USD type name for this structural type.
	public var typeName: String { rawValue }

	/// A human-readable display name.
	public var displayName: String {
		switch self {
		case .xform: return "Transform"
		case .scope: return "Scope"
		}
	}

	/// The SF Symbol icon name for this type.
	public var iconName: String {
		switch self {
		case .xform: return "move.3d"
		case .scope: return "folder"
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

public struct USDSceneBounds: Sendable, Equatable {
	public var min: SIMD3<Float>
	public var max: SIMD3<Float>
	public var center: SIMD3<Float>
	public var maxExtent: Float

	public init(min: SIMD3<Float>, max: SIMD3<Float>, center: SIMD3<Float>, maxExtent: Float) {
		self.min = min
		self.max = max
		self.center = center
		self.maxExtent = maxExtent
	}
}

public enum DeconstructedUSDInterop {
	private static let advancedClient = USDInteropAdvancedCore.USDAdvancedClient()

	// MARK: - Materials

	public static func allMaterials(url: URL) -> [USDMaterialInfo] {
		advancedClient.allMaterials(url: url)
	}

	public static func materialBinding(url: URL, primPath: String) -> String? {
		advancedClient.materialBinding(url: url, path: primPath)
	}

	public static func setMaterialBinding(
		url: URL,
		primPath: String,
		materialPath: String,
		editTarget: USDLayerEditTarget = .rootLayer
	) throws {
		do {
			try advancedClient.setMaterialBinding(
				url: url,
				primPath: primPath,
				materialPath: materialPath,
				editTarget: editTarget
			)
		} catch {
			throw mapAdvancedError(error, url: url, primPath: primPath, schema: nil)
		}
	}

	public static func clearMaterialBinding(
		url: URL,
		primPath: String,
		editTarget: USDLayerEditTarget = .rootLayer
	) throws {
		do {
			try advancedClient.clearMaterialBinding(
				url: url,
				primPath: primPath,
				editTarget: editTarget
			)
		} catch {
			throw mapAdvancedError(error, url: url, primPath: primPath, schema: nil)
		}
	}

	public static func materialBindingStrength(url: URL, primPath: String) -> USDMaterialBindingStrength? {
		advancedClient.materialBindingStrength(url: url, path: primPath)
	}

	public static func setMaterialBindingStrength(
		url: URL,
		primPath: String,
		strength: USDMaterialBindingStrength,
		editTarget: USDLayerEditTarget = .rootLayer
	) throws {
		do {
			try advancedClient.setMaterialBindingStrength(
				url: url,
				primPath: primPath,
				strength: strength,
				editTarget: editTarget
			)
		} catch {
			throw mapAdvancedError(error, url: url, primPath: primPath, schema: nil)
		}
	}

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

	/// Creates a primitive shape in the USD scene.
	///
	/// - Parameters:
	///   - url: The USD file to modify.
	///   - parentPath: The parent prim path (e.g., "/Root"). Pass "/" for root level.
	///   - primitiveType: The type of primitive shape to create.
	///   - name: Optional custom name. If nil, a unique name will be generated.
	/// - Returns: The full path of the created prim.
	public static func createPrimitive(
		url: URL,
		parentPath: String,
		primitiveType: USDPrimitiveType,
		name: String? = nil
	) throws -> String {
		let primName = try name ?? generateUniqueName(
			url: url,
			parentPath: parentPath,
			baseName: primitiveType.displayName
		)
		do {
			let createdPath = try advancedClient.createPrim(
				url: url,
				parentPath: parentPath,
				name: primName,
				typeName: primitiveType.typeName
			)
			try advancedClient.applyPrimitiveDefaults(url: url, primPath: createdPath, preset: .rcp)
			return createdPath
		} catch {
			throw mapAdvancedError(error, url: url, primPath: parentPath, schema: nil)
		}
	}

	/// Creates a structural prim (Xform or Scope) in the USD scene.
	///
	/// - Parameters:
	///   - url: The USD file to modify.
	///   - parentPath: The parent prim path (e.g., "/Root"). Pass "/" for root level.
	///   - structuralType: The type of structural prim to create.
	///   - name: Optional custom name. If nil, a unique name will be generated.
	/// - Returns: The full path of the created prim.
	public static func createStructural(
		url: URL,
		parentPath: String,
		structuralType: USDStructuralType,
		name: String? = nil
	) throws -> String {
		let primName = try name ?? generateUniqueName(
			url: url,
			parentPath: parentPath,
			baseName: structuralType.displayName
		)
		do {
			return try advancedClient.createPrim(
				url: url,
				parentPath: parentPath,
				name: primName,
				typeName: structuralType.typeName
			)
		} catch {
			throw mapAdvancedError(error, url: url, primPath: parentPath, schema: nil)
		}
	}

	/// Generates a unique name for a new prim by appending a numeric suffix if needed.
	private static func generateUniqueName(
		url: URL,
		parentPath: String,
		baseName: String
	) throws -> String {
		let existingNames: Set<String>
		do {
			existingNames = Set(try advancedClient.existingPrimNames(url: url, parentPath: parentPath))
		} catch {
			// If we can't get existing names (e.g., parent doesn't exist), use base name
			return baseName
		}

		if !existingNames.contains(baseName) {
			return baseName
		}

		// Find the next available suffix
		var suffix = 1
		while existingNames.contains("\(baseName)_\(suffix)") {
			suffix += 1
		}
		return "\(baseName)_\(suffix)"
	}

	/// Compute scene bounds by iterating mesh points.
	/// Returns scene bounds for camera framing.
	public static func getSceneBounds(url: URL) throws -> USDSceneBounds {
		if let bounds = USDInteropStage.sceneBounds(url: url) {
			return USDSceneBounds(
				min: bounds.min,
				max: bounds.max,
				center: bounds.center,
				maxExtent: bounds.maxExtent
			)
		}
		return USDSceneBounds(min: .zero, max: .zero, center: .zero, maxExtent: 0)
	}

	/// Returns the scene graph JSON produced by the low-level interop layer.
	public static func sceneGraphJSON(url: URL) -> String? {
		USDInteropStage.sceneGraphJSON(url: url)
	}

	/// Exports USDA text from the low-level interop layer.
	public static func exportUSDA(url: URL) -> String? {
		USDInteropStage.exportUSDA(url: url)
	}

	/// Retrieves stage metadata including layer data properties.
	/// Returns USDStageMetadata containing defaultPrim, metersPerUnit, upAxis, etc.
	public static func getStageMetadata(url: URL) -> USDStageMetadata {
		return advancedClient.stageMetadata(url: url)
	}

	/// Retrieves key prim attributes for inspection.
	public static func getPrimAttributes(
		url: URL,
		primPath: String
	) -> USDPrimAttributes? {
		advancedClient.primAttributes(url: url, path: primPath)
	}

	public static func getPrimTransform(
		url: URL,
		primPath: String
	) -> USDTransformData? {
		advancedClient.primTransform(url: url, path: primPath)
	}

	public static func getPrimReferences(
		url: URL,
		primPath: String
	) -> [USDReference] {
		advancedClient.primReferences(url: url, path: primPath)
	}

	public static func listPrimVariantSets(
		url: URL,
		primPath: String
	) throws -> [USDVariantSetDescriptor] {
		do {
			return try advancedClient.listVariantSets(
				url: url,
				scope: .prim(path: primPath)
			)
		} catch {
			throw mapAdvancedError(error, url: url, primPath: primPath, schema: nil)
		}
	}

	public static func setPrimVariantSelection(
		url: URL,
		primPath: String,
		setName: String,
		selectionId: String?,
		editTarget: USDLayerEditTarget = .rootLayer,
		persist: Bool = true
	) throws {
		let request = USDVariantSelectionRequest(
			scope: .prim(path: primPath),
			setName: setName,
			selectionId: selectionId
		)
		let variantTarget: USDVariantEditTarget = switch editTarget {
		case .sessionLayer:
			.sessionLayer
		case .rootLayer:
			.rootLayer
		@unknown default:
			.rootLayer
		}
		do {
			try advancedClient.applyVariantSelection(
				url: url,
				request: request,
				editTarget: variantTarget,
				persist: persist
			)
		} catch {
			throw mapAdvancedError(error, url: url, primPath: primPath, schema: nil)
		}
	}

	public static func addPrimReference(
		url: URL,
		primPath: String,
		reference: USDReference,
		editTarget: USDLayerEditTarget = .rootLayer
	) throws {
		do {
			try advancedClient.addReference(
				url: url,
				primPath: primPath,
				reference: reference,
				editTarget: editTarget
			)
		} catch {
			throw mapAdvancedError(error, url: url, primPath: primPath, schema: nil)
		}
	}

	public static func removePrimReference(
		url: URL,
		primPath: String,
		reference: USDReference,
		editTarget: USDLayerEditTarget = .rootLayer
	) throws {
		do {
			try advancedClient.removeReference(
				url: url,
				primPath: primPath,
				reference: reference,
				editTarget: editTarget
			)
		} catch {
			throw mapAdvancedError(error, url: url, primPath: primPath, schema: nil)
		}
	}

	public static func setPrimTransform(
		url: URL,
		primPath: String,
		transform: USDTransformData
	) throws {
		do {
			try advancedClient.setPrimTransform(url: url, path: primPath, transform: transform)
		} catch {
			throw mapAdvancedError(error, url: url, primPath: primPath, schema: nil)
		}
	}
	/// Sets the metersPerUnit metadata for the stage.
	public static func setMetersPerUnit(url: URL, value: Double) throws {
		do {
			try advancedClient.setMetersPerUnit(url: url, value: value)
		} catch {
			throw mapAdvancedError(error, url: url, primPath: "/", schema: nil)
		}
	}
	/// Sets the upAxis metadata for the stage.
	public static func setUpAxis(url: URL, axis: String) throws {
		do {
			try advancedClient.setUpAxis(url: url, axis: axis)
		} catch {
			throw mapAdvancedError(error, url: url, primPath: "/", schema: nil)
		}
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
		if let advancedError = error as? USDInteropAdvancedCore.USDAdvancedError {
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
			default:
				return error
			}
		}
		return error
	}

}
