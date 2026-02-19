import CxxStdlib
import Foundation
@_implementationOnly import OpenUSD
import USDInterfaces
import USDInterop
import USDInteropAdvanced
import USDInteropAdvancedCore
import USDInteropAdvancedEditing
import USDInteropAdvancedInspection

// Local aliases for OpenUSD imported C++ symbols.
// Keep these fileprivate so OpenUSD internals never leak into the module API.
fileprivate typealias UsdStage = pxrInternal_v0_25_8__pxrReserved__.UsdStage
fileprivate typealias SdfPath = pxrInternal_v0_25_8__pxrReserved__.SdfPath
fileprivate typealias TfToken = pxrInternal_v0_25_8__pxrReserved__.TfToken
fileprivate typealias SdfValueTypeName = pxrInternal_v0_25_8__pxrReserved__.SdfValueTypeName
fileprivate typealias SdfVariability = pxrInternal_v0_25_8__pxrReserved__.SdfVariability
fileprivate typealias UsdTimeCode = pxrInternal_v0_25_8__pxrReserved__.UsdTimeCode
fileprivate typealias VtValue = pxrInternal_v0_25_8__pxrReserved__.VtValue
fileprivate typealias GfVec2f = pxrInternal_v0_25_8__pxrReserved__.GfVec2f
fileprivate typealias GfVec3f = pxrInternal_v0_25_8__pxrReserved__.GfVec3f
fileprivate typealias GfQuatf = pxrInternal_v0_25_8__pxrReserved__.GfQuatf
fileprivate typealias SdfAssetPath = pxrInternal_v0_25_8__pxrReserved__.SdfAssetPath

private enum USDMutationCoordinator {
	static let lock = NSLock()

	static func withLock<T>(_ operation: () throws -> T) rethrows -> T {
		lock.lock()
		defer { lock.unlock() }
		return try operation()
	}
}

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
	case componentAuthoringFailed(reason: String)
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
		case let .componentAuthoringFailed(reason):
			return "Failed to author component: \(reason)"
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

public struct RealityKitComponentPrimInfo: Sendable, Hashable {
	public var path: String
	public var primName: String
	public var typeName: String
	public var isActive: Bool

	public init(path: String, primName: String, typeName: String, isActive: Bool) {
		self.path = path
		self.primName = primName
		self.typeName = typeName
		self.isActive = isActive
	}
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

	/// Adds a RealityKitComponent prim under the specified prim and authors its `info:id`.
	///
	/// - Important: Initial MVP implementation operates on USDA text.
	@discardableResult
	public static func addRealityKitComponent(
		url: URL,
		primPath: String,
		componentName: String,
		componentIdentifier: String
	) throws -> String {
		guard url.pathExtension.lowercased() == "usda" else {
			throw DeconstructedUSDInteropError.componentAuthoringFailed(
				reason: "Only .usda scenes are supported for initial component authoring."
			)
		}
		let source: String
		do {
			source = try String(contentsOf: url, encoding: .utf8)
		} catch {
			throw DeconstructedUSDInteropError.componentAuthoringFailed(
				reason: "Unable to read USDA scene."
			)
		}

		let updated = try insertRealityKitComponent(
			in: source,
			primPath: primPath,
			componentName: componentName,
			componentIdentifier: componentIdentifier
		)
		do {
			try updated.write(to: url, atomically: true, encoding: .utf8)
		} catch {
			throw DeconstructedUSDInteropError.componentAuthoringFailed(
				reason: "Unable to write USDA scene."
			)
		}
		return "\(primPath)/\(componentName)"
	}

	@discardableResult
	public static func ensureRealityKitMeshSortingGroup(
		url: URL,
		groupPrimPath: String
	) throws -> String {
		guard url.pathExtension.lowercased() == "usda" else {
			throw DeconstructedUSDInteropError.componentAuthoringFailed(
				reason: "Only .usda scenes are supported for model sorting group authoring."
			)
		}
		if getPrimAttributes(url: url, primPath: groupPrimPath) != nil {
			return groupPrimPath
		}
		guard let parentPath = parentPath(of: groupPrimPath),
		      let groupName = primName(of: groupPrimPath)
		else {
			throw DeconstructedUSDInteropError.componentAuthoringFailed(
				reason: "Invalid model sorting group path: \(groupPrimPath)"
			)
		}
		let source: String
		do {
			source = try String(contentsOf: url, encoding: .utf8)
		} catch {
			throw DeconstructedUSDInteropError.componentAuthoringFailed(
				reason: "Unable to read USDA scene."
			)
		}
		let updated = try insertTypedPrimInUSDA(
			source,
			parentPrimPath: parentPath,
			typeName: "RealityKitMeshSortingGroup",
			primName: groupName
		)
		do {
			try updated.write(to: url, atomically: true, encoding: .utf8)
		} catch {
			throw DeconstructedUSDInteropError.componentAuthoringFailed(
				reason: "Unable to write USDA scene."
			)
		}
		try setRealityKitComponentParameter(
			url: url,
			componentPrimPath: groupPrimPath,
			attributeType: "token",
			attributeName: "depthPass",
			valueLiteral: "\"None\""
		)
		return groupPrimPath
	}

	@discardableResult
	public static func ensureTypedPrim(
		url: URL,
		parentPrimPath: String,
		typeName: String,
		primName: String
	) throws -> String {
		guard url.pathExtension.lowercased() == "usda" else {
			throw DeconstructedUSDInteropError.componentAuthoringFailed(
				reason: "Only .usda scenes are supported for typed prim authoring."
			)
		}
		let source: String
		do {
			source = try String(contentsOf: url, encoding: .utf8)
		} catch {
			throw DeconstructedUSDInteropError.componentAuthoringFailed(
				reason: "Unable to read USDA scene."
			)
		}
		let updated = try insertTypedPrimInUSDA(
			source,
			parentPrimPath: parentPrimPath,
			typeName: typeName,
			primName: primName
		)
		do {
			try updated.write(to: url, atomically: true, encoding: .utf8)
		} catch {
			throw DeconstructedUSDInteropError.componentAuthoringFailed(
				reason: "Unable to write USDA scene."
			)
		}
		return "\(parentPrimPath)/\(primName)"
	}

	public static func setAudioLibraryResources(
		url: URL,
		audioLibraryComponentPath: String,
		keys: [String],
		valueTargets: [String]
	) throws {
		guard keys.count == valueTargets.count else {
			throw DeconstructedUSDInteropError.componentAuthoringFailed(
				reason: "AudioLibrary resources keys and values must have the same count."
			)
		}
		let resourcesPath = "\(audioLibraryComponentPath)/resources"
		_ = try ensureTypedPrim(
			url: url,
			parentPrimPath: audioLibraryComponentPath,
			typeName: "RealityKitDict",
			primName: "resources"
		)
		try setRealityKitComponentParameter(
			url: url,
			componentPrimPath: resourcesPath,
			attributeType: "string[]",
			attributeName: "keys",
			valueLiteral: formatUSDStringArray(keys)
		)
		try setRealityKitComponentParameter(
			url: url,
			componentPrimPath: resourcesPath,
			attributeType: "rel",
			attributeName: "values",
			valueLiteral: formatUSDRelationshipTargets(valueTargets)
		)
	}

	public static func upsertRealityKitAudioFile(
		url: URL,
		primPath: String,
		relativeAssetPath: String,
		shouldLoop: Bool
	) throws {
		guard let parent = parentPath(of: primPath),
		      let name = primName(of: primPath)
		else {
			throw DeconstructedUSDInteropError.componentAuthoringFailed(
				reason: "Invalid RealityKitAudioFile path: \(primPath)"
			)
		}
		_ = try ensureTypedPrim(
			url: url,
			parentPrimPath: parent,
			typeName: "RealityKitAudioFile",
			primName: name
		)
		try setRealityKitComponentParameter(
			url: url,
			componentPrimPath: primPath,
			attributeType: "uniform asset",
			attributeName: "file",
			valueLiteral: "@\(relativeAssetPath)@"
		)
		try setRealityKitComponentParameter(
			url: url,
			componentPrimPath: primPath,
			attributeType: "uniform bool",
			attributeName: "shouldLoop",
			valueLiteral: shouldLoop ? "1" : "0"
		)
	}

	public static func deletePrimAtPath(
		url: URL,
		primPath: String
	) throws {
		try deletePrim(url: url, primPath: primPath)
	}

	public static func setRealityKitComponentActive(
		url: URL,
		componentPrimPath: String,
		isActive: Bool
	) throws {
		try setPrimActive(url: url, primPath: componentPrimPath, isActive: isActive)
	}

	public static func deleteRealityKitComponent(
		url: URL,
		componentPrimPath: String
	) throws {
		try deletePrim(url: url, primPath: componentPrimPath)
	}

	public static func setRealityKitComponentParameter(
		url: URL,
		componentPrimPath: String,
		attributeType: String,
		attributeName: String,
		valueLiteral: String
	) throws {
		try USDMutationCoordinator.withLock {
			if try setComponentParameterWithUSDMutation(
				url: url,
				componentPrimPath: componentPrimPath,
				attributeType: attributeType,
				attributeName: attributeName,
				valueLiteral: valueLiteral
			) {
				return
			}

			guard url.pathExtension.lowercased() == "usda" else {
				throw DeconstructedUSDInteropError.componentAuthoringFailed(
					reason: "Only .usda scenes are supported for initial component parameter editing."
				)
			}
			let source: String
			do {
				source = try String(contentsOf: url, encoding: .utf8)
			} catch {
				throw DeconstructedUSDInteropError.componentAuthoringFailed(
					reason: "Unable to read USDA scene."
				)
			}

			let updated = try updateRealityKitComponentParameterInUSDA(
				source,
				componentPrimPath: componentPrimPath,
				attributeType: attributeType,
				attributeName: attributeName,
				valueLiteral: valueLiteral
			)
			do {
				try updated.write(to: url, atomically: true, encoding: .utf8)
			} catch {
				throw DeconstructedUSDInteropError.componentAuthoringFailed(
					reason: "Unable to write USDA scene."
				)
			}
		}
	}

	public static func deleteRealityKitComponentParameter(
		url: URL,
		componentPrimPath: String,
		attributeName: String
	) throws {
		try USDMutationCoordinator.withLock {
			if try deleteComponentParameterWithUSDMutation(
				url: url,
				componentPrimPath: componentPrimPath,
				attributeName: attributeName
			) {
				return
			}

			guard url.pathExtension.lowercased() == "usda" else {
				throw DeconstructedUSDInteropError.componentAuthoringFailed(
					reason: "Only .usda scenes are supported for initial component parameter editing."
				)
			}
			let source: String
			do {
				source = try String(contentsOf: url, encoding: .utf8)
			} catch {
				throw DeconstructedUSDInteropError.componentAuthoringFailed(
					reason: "Unable to read USDA scene."
				)
			}

			let updated = try removeRealityKitComponentParameterInUSDA(
				source,
				componentPrimPath: componentPrimPath,
				attributeName: attributeName
			)
			do {
				try updated.write(to: url, atomically: true, encoding: .utf8)
			} catch {
				throw DeconstructedUSDInteropError.componentAuthoringFailed(
					reason: "Unable to write USDA scene."
				)
			}
		}
	}

	public static func listRealityKitComponentPrims(
		url: URL,
		parentPrimPath: String
	) -> [RealityKitComponentPrimInfo] {
		guard url.pathExtension.lowercased() == "usda" else {
			return []
		}
		guard let source = try? String(contentsOf: url, encoding: .utf8) else {
			return []
		}
		return parseRealityKitComponentPrimsFromUSDA(
			source: source,
			parentPrimPath: parentPrimPath
		)
	}

	public static func realityKitComponentCustomDataAsset(
		url: URL,
		componentPrimPath: String,
		key: String
	) -> String? {
		guard url.pathExtension.lowercased() == "usda" else {
			return nil
		}
		guard let source = try? String(contentsOf: url, encoding: .utf8) else {
			return nil
		}
		return parseComponentCustomDataAssetFromUSDA(
			source: source,
			componentPrimPath: componentPrimPath,
			key: key
		)
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

private func formatUSDStringArray(_ values: [String]) -> String {
	let escaped = values.map { value in
		"\"\(value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\""
	}
	return "[\(escaped.joined(separator: ", "))]"
}

private func formatUSDRelationshipTargets(_ primPaths: [String]) -> String {
	let targets = primPaths.map { "<\($0)>" }
	switch targets.count {
	case 0:
		return "[]"
	case 1:
		return targets[0]
	default:
		return "[\(targets.joined(separator: ", "))]"
	}
}

private struct USDAPrimContext {
	let path: String
	let indent: String
}

private struct ComponentTemplateLine {
	let level: Int
	let text: String
}

private struct ComponentTemplate {
	let preInfo: [ComponentTemplateLine]
	let postInfo: [ComponentTemplateLine]

	static let none = ComponentTemplate(preInfo: [], postInfo: [])
}

private func template(for componentIdentifier: String) -> ComponentTemplate {
	switch componentIdentifier {
	case "RealityKit.Anchoring":
		return ComponentTemplate(
			preInfo: [],
			postInfo: [
				.init(level: 0, text: ""),
				.init(level: 0, text: "def RealityKitStruct \"descriptor\""),
				.init(level: 0, text: "{"),
				.init(level: 0, text: "}")
			]
		)
	case "RealityKit.CharacterController":
		return ComponentTemplate(
			preInfo: [],
			postInfo: [
				.init(level: 0, text: ""),
				.init(level: 0, text: "def RealityKitStruct \"m_controllerDesc\""),
				.init(level: 0, text: "{"),
				.init(level: 1, text: "def RealityKitStruct \"collisionFilter\""),
				.init(level: 1, text: "{"),
				.init(level: 1, text: "}"),
				.init(level: 0, text: "}")
			]
		)
	case "RealityKit.CustomDockingRegion":
		return ComponentTemplate(
			preInfo: [],
			postInfo: [
				.init(level: 0, text: ""),
				.init(level: 0, text: "def RealityKitStruct \"m_bounds\""),
				.init(level: 0, text: "{"),
				.init(level: 1, text: "float3 max = (1.2, 0.5, 0)"),
				.init(level: 1, text: "float3 min = (-1.2, -0.5, -0)"),
				.init(level: 0, text: "}")
			]
		)
	case "RealityKit.VFXEmitter":
		return ComponentTemplate(
			preInfo: [],
			postInfo: [
				.init(level: 0, text: ""),
				.init(level: 0, text: "def RealityKitStruct \"currentState\""),
				.init(level: 0, text: "{"),
				.init(level: 1, text: "def RealityKitStruct \"mainEmitter\""),
				.init(level: 1, text: "{"),
				.init(level: 1, text: "}"),
				.init(level: 1, text: ""),
				.init(level: 1, text: "def RealityKitStruct \"spawnedEmitter\""),
				.init(level: 1, text: "{"),
				.init(level: 1, text: "}"),
				.init(level: 0, text: "}")
			]
		)
	case "RealityKit.DirectionalLight", "RealityKit.SpotLight":
		return ComponentTemplate(
			preInfo: [],
			postInfo: [
				.init(level: 0, text: ""),
				.init(level: 0, text: "def RealityKitStruct \"Shadow\""),
				.init(level: 0, text: "{"),
				.init(level: 0, text: "}")
			]
		)
	case "RealityKit.VirtualEnvironmentProbe":
		return ComponentTemplate(
			preInfo: [
				.init(level: 0, text: "token blendMode = \"single\"")
			],
			postInfo: [
				.init(level: 0, text: ""),
				.init(level: 0, text: "def RealityKitStruct \"Resource1\""),
				.init(level: 0, text: "{"),
				.init(level: 0, text: "}"),
				.init(level: 0, text: ""),
				.init(level: 0, text: "def RealityKitStruct \"Resource2\""),
				.init(level: 0, text: "{"),
				.init(level: 0, text: "}")
			]
		)
	case "RealityKit.Collider":
		return ComponentTemplate(
			preInfo: [
				.init(level: 0, text: "uint group = 1")
			],
			postInfo: [
				.init(level: 0, text: "uint mask = 4294967295"),
				.init(level: 0, text: "token type = \"Default\""),
				.init(level: 0, text: ""),
				.init(level: 0, text: "def RealityKitStruct \"Shape\""),
				.init(level: 0, text: "{"),
				.init(level: 1, text: "float3 extent = (0.2, 0.2, 0.2)"),
				.init(level: 1, text: "token shapeType = \"Box\""),
				.init(level: 1, text: ""),
				.init(level: 1, text: "def RealityKitStruct \"pose\""),
				.init(level: 1, text: "{"),
				.init(level: 1, text: "}"),
				.init(level: 0, text: "}")
			]
		)
	case "RealityKit.RigidBody":
		return ComponentTemplate(
			preInfo: [],
			postInfo: [
				.init(level: 0, text: ""),
				.init(level: 0, text: "def RealityKitStruct \"massFrame\""),
				.init(level: 0, text: "{"),
				.init(level: 1, text: "def RealityKitStruct \"m_pose\""),
				.init(level: 1, text: "{"),
				.init(level: 1, text: "}"),
				.init(level: 0, text: "}"),
				.init(level: 0, text: ""),
				.init(level: 0, text: "def RealityKitStruct \"material\""),
				.init(level: 0, text: "{"),
				.init(level: 0, text: "}")
			]
		)
	default:
		return .none
	}
}

private func renderTemplateLines(
	_ lines: [ComponentTemplateLine],
	fieldIndent: String,
	indentUnit: String
) -> [String] {
	lines.map { line in
		guard !line.text.isEmpty else { return "" }
		let extraIndent = String(repeating: indentUnit, count: max(0, line.level))
		return fieldIndent + extraIndent + line.text
	}
}

private func insertRealityKitComponent(
	in source: String,
	primPath: String,
	componentName: String,
	componentIdentifier: String
) throws -> String {
	let lines = source.split(whereSeparator: \.isNewline).map(String.init)
	let indentUnit = source.contains("\t") ? "\t" : "    "
	let declarationRegex = /^(\s*)(def|over|class)\s+(?:([A-Za-z0-9_:]+)\s+)?\"([^\"]+)\"/

	var stack: [USDAPrimContext] = []
	var pending: USDAPrimContext?
	var insertionLineIndex: Int?
	var targetIndent: String?
	var inTargetPrim = false

	for (index, line) in lines.enumerated() {
		if let match = line.firstMatch(of: declarationRegex) {
			let indent = String(match.output.1)
			let primName = String(match.output.4)
			let path = if let parent = stack.last?.path {
				"\(parent)/\(primName)"
			} else {
				"/\(primName)"
			}
			let context = USDAPrimContext(path: path, indent: indent)
			if line.contains("{") {
				stack.append(context)
				inTargetPrim = context.path == primPath
				if inTargetPrim {
					targetIndent = context.indent
				}
			} else {
				pending = context
			}
		}

		if line.contains("{"), let pendingContext = pending {
			stack.append(pendingContext)
			inTargetPrim = pendingContext.path == primPath
			if inTargetPrim {
				targetIndent = pendingContext.indent
			}
			pending = nil
		}

		let closingCount = line.filter { $0 == "}" }.count
		if closingCount > 0 {
			for _ in 0..<closingCount {
				guard let current = stack.last else { break }
				if current.path == primPath && insertionLineIndex == nil {
					insertionLineIndex = index
				}
				_ = stack.popLast()
				inTargetPrim = stack.last?.path == primPath
			}
		}

		if inTargetPrim,
		   line.contains("def RealityKitComponent \"\(componentName)\"") {
			throw DeconstructedUSDInteropError.componentAuthoringFailed(
				reason: "Component '\(componentName)' already exists on prim \(primPath)."
			)
		}
	}

	guard let insertionLineIndex,
	      let targetIndent else {
		throw DeconstructedUSDInteropError.componentAuthoringFailed(
			reason: "Target prim not found: \(primPath)"
		)
	}

	let componentIndent = targetIndent + indentUnit
	let fieldIndent = componentIndent + indentUnit
	let componentTemplate = template(for: componentIdentifier)
	let preInfoLines = renderTemplateLines(
		componentTemplate.preInfo,
		fieldIndent: fieldIndent,
		indentUnit: indentUnit
	)
	let postInfoLines = renderTemplateLines(
		componentTemplate.postInfo,
		fieldIndent: fieldIndent,
		indentUnit: indentUnit
	)
	let componentBlock: [String] = [
		"",
		"\(componentIndent)def RealityKitComponent \"\(componentName)\"",
		"\(componentIndent){",
	] + preInfoLines + [
		"\(fieldIndent)uniform token info:id = \"\(componentIdentifier)\"",
	] + postInfoLines + [
		"\(componentIndent)}"
	]

	var updatedLines = lines
	updatedLines.insert(contentsOf: componentBlock, at: insertionLineIndex)
	let updated = updatedLines.joined(separator: "\n")
	return source.hasSuffix("\n") ? updated + "\n" : updated
}

private func setPrimActive(
	url: URL,
	primPath: String,
	isActive: Bool
) throws {
	let stagePtr = UsdStage.Open(std.string(url.path), UsdStage.InitialLoadSet.LoadAll)
	guard stagePtr._isNonnull() else {
		throw DeconstructedUSDInteropError.stageOpenFailed(url)
	}
	let stage = OpenUSD.Overlay.Dereference(stagePtr)
	let prim = stage.GetPrimAtPath(SdfPath(std.string(primPath)))
	guard prim.IsValid() else {
		throw DeconstructedUSDInteropError.primNotFound(primPath)
	}
	prim.SetActive(isActive)
	let rootLayerHandle = stage.GetRootLayer()
	guard Bool(rootLayerHandle) else {
		throw DeconstructedUSDInteropError.rootLayerMissing(url)
	}
	let rootLayer = OpenUSD.Overlay.Dereference(rootLayerHandle)
	guard rootLayer.Save(false) else {
		throw DeconstructedUSDInteropError.saveFailed(url)
	}
}

private func deletePrim(
	url: URL,
	primPath: String
) throws {
	let stagePtr = UsdStage.Open(std.string(url.path), UsdStage.InitialLoadSet.LoadAll)
	guard stagePtr._isNonnull() else {
		throw DeconstructedUSDInteropError.stageOpenFailed(url)
	}
	let stage = OpenUSD.Overlay.Dereference(stagePtr)
	let prim = stage.GetPrimAtPath(SdfPath(std.string(primPath)))
	guard prim.IsValid() else {
		throw DeconstructedUSDInteropError.primNotFound(primPath)
	}
	_ = stage.RemovePrim(SdfPath(std.string(primPath)))
	let rootLayerHandle = stage.GetRootLayer()
	guard Bool(rootLayerHandle) else {
		throw DeconstructedUSDInteropError.rootLayerMissing(url)
	}
	let rootLayer = OpenUSD.Overlay.Dereference(rootLayerHandle)
	guard rootLayer.Save(false) else {
		throw DeconstructedUSDInteropError.saveFailed(url)
	}
}

private func setComponentParameterWithUSDMutation(
	url: URL,
	componentPrimPath: String,
	attributeType: String,
	attributeName: String,
	valueLiteral: String
) throws -> Bool {
	let stagePtr = UsdStage.Open(std.string(url.path), UsdStage.InitialLoadSet.LoadAll)
	guard stagePtr._isNonnull() else {
		throw DeconstructedUSDInteropError.stageOpenFailed(url)
	}
	let stage = OpenUSD.Overlay.Dereference(stagePtr)
	let prim = stage.GetPrimAtPath(SdfPath(std.string(componentPrimPath)))
	guard prim.IsValid() else {
		throw DeconstructedUSDInteropError.primNotFound(componentPrimPath)
	}

	let normalizedType = normalizeAttributeType(attributeType)
	let token = TfToken(std.string(attributeName))
	let variability = isUniformAttributeType(attributeType)
		? SdfVariability.SdfVariabilityUniform
		: SdfVariability.SdfVariabilityVarying

	let didAuthor: Bool
	switch normalizedType {
	case "bool":
		guard let value = parseUSDBoolLiteral(valueLiteral) else { return false }
		let attr = prim.CreateAttribute(token, SdfValueTypeName.Bool, false, variability)
		didAuthor = attr.Set(VtValue(value), UsdTimeCode.Default())
	case "int":
		guard
			let parsed = parseUSDIntLiteral(valueLiteral),
			let value = Int32(exactly: parsed)
		else { return false }
		let attr = prim.CreateAttribute(token, SdfValueTypeName.Int, false, variability)
		didAuthor = attr.Set(VtValue(value), UsdTimeCode.Default())
	case "uint":
		guard
			let parsed = parseUSDUIntLiteral(valueLiteral),
			let value = UInt32(exactly: parsed)
		else { return false }
		let attr = prim.CreateAttribute(token, SdfValueTypeName.UInt, false, variability)
		didAuthor = attr.Set(VtValue(value), UsdTimeCode.Default())
	case "float":
		guard let value = parseUSDFloatLiteral(valueLiteral) else { return false }
		let attr = prim.CreateAttribute(token, SdfValueTypeName.Float, false, variability)
		didAuthor = attr.Set(VtValue(value), UsdTimeCode.Default())
	case "double":
		guard let value = parseUSDDoubleLiteral(valueLiteral) else { return false }
		let attr = prim.CreateAttribute(token, SdfValueTypeName.Double, false, variability)
		didAuthor = attr.Set(VtValue(value), UsdTimeCode.Default())
	case "string":
		let value = parseUSDQuotedStringLiteral(valueLiteral)
		let attr = prim.CreateAttribute(token, SdfValueTypeName.String, false, variability)
		didAuthor = attr.Set(VtValue(std.string(value)), UsdTimeCode.Default())
	case "token":
		let value = parseUSDQuotedStringLiteral(valueLiteral)
		let attr = prim.CreateAttribute(token, SdfValueTypeName.Token, false, variability)
		didAuthor = attr.Set(VtValue(TfToken(std.string(value))), UsdTimeCode.Default())
	case "asset":
		guard let value = parseUSDAssetLiteral(valueLiteral) else { return false }
		let attr = prim.CreateAttribute(token, SdfValueTypeName.Asset, false, variability)
		didAuthor = attr.Set(VtValue(SdfAssetPath(std.string(value))), UsdTimeCode.Default())
	case "float2":
		guard let value = parseUSDFloatTuple(valueLiteral, count: 2) else { return false }
		let attr = prim.CreateAttribute(token, SdfValueTypeName.Float2, false, variability)
		didAuthor = attr.Set(VtValue(GfVec2f(Float(value[0]), Float(value[1]))), UsdTimeCode.Default())
	case "float3":
		guard let value = parseUSDFloatTuple(valueLiteral, count: 3) else { return false }
		let attr = prim.CreateAttribute(token, SdfValueTypeName.Float3, false, variability)
		didAuthor = attr.Set(
			VtValue(GfVec3f(Float(value[0]), Float(value[1]), Float(value[2]))),
			UsdTimeCode.Default()
		)
	case "quatf":
		guard let value = parseUSDFloatTuple(valueLiteral, count: 4) else { return false }
		let attr = prim.CreateAttribute(token, SdfValueTypeName.Quatf, false, variability)
		didAuthor = attr.Set(
			VtValue(
				GfQuatf(
					Float(value[0]),
					GfVec3f(Float(value[1]), Float(value[2]), Float(value[3]))
				)
			),
			UsdTimeCode.Default()
		)
	default:
		return false
	}

	guard didAuthor else {
		throw DeconstructedUSDInteropError.componentAuthoringFailed(
			reason: "Failed to set \(attributeName) on \(componentPrimPath)."
		)
	}
	let rootLayerHandle = stage.GetRootLayer()
	guard Bool(rootLayerHandle) else {
		throw DeconstructedUSDInteropError.rootLayerMissing(url)
	}
	let rootLayer = OpenUSD.Overlay.Dereference(rootLayerHandle)
	guard rootLayer.Save(false) else {
		throw DeconstructedUSDInteropError.saveFailed(url)
	}
	return true
}

private func deleteComponentParameterWithUSDMutation(
	url: URL,
	componentPrimPath: String,
	attributeName: String
) throws -> Bool {
	let stagePtr = UsdStage.Open(std.string(url.path), UsdStage.InitialLoadSet.LoadAll)
	guard stagePtr._isNonnull() else {
		throw DeconstructedUSDInteropError.stageOpenFailed(url)
	}
	let stage = OpenUSD.Overlay.Dereference(stagePtr)
	let prim = stage.GetPrimAtPath(SdfPath(std.string(componentPrimPath)))
	guard prim.IsValid() else {
		throw DeconstructedUSDInteropError.primNotFound(componentPrimPath)
	}
	let token = TfToken(std.string(attributeName))
	let attribute = prim.GetAttribute(token)
	guard attribute.IsValid() else {
		return false
	}
	_ = attribute.Clear()

	let rootLayerHandle = stage.GetRootLayer()
	guard Bool(rootLayerHandle) else {
		throw DeconstructedUSDInteropError.rootLayerMissing(url)
	}
	let rootLayer = OpenUSD.Overlay.Dereference(rootLayerHandle)
	guard rootLayer.Save(false) else {
		throw DeconstructedUSDInteropError.saveFailed(url)
	}
	return true
}

private func normalizeAttributeType(_ raw: String) -> String {
	let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
	if trimmed.hasPrefix("uniform ") {
		return String(trimmed.dropFirst("uniform ".count))
	}
	return trimmed
}

private func isUniformAttributeType(_ raw: String) -> Bool {
	raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().hasPrefix("uniform ")
}

private func parseUSDBoolLiteral(_ raw: String) -> Bool? {
	switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
	case "true", "1":
		return true
	case "false", "0":
		return false
	default:
		return nil
	}
}

private func parseUSDIntLiteral(_ raw: String) -> Int? {
	Int(raw.trimmingCharacters(in: .whitespacesAndNewlines))
}

private func parseUSDUIntLiteral(_ raw: String) -> UInt? {
	UInt(raw.trimmingCharacters(in: .whitespacesAndNewlines))
}

private func parseUSDFloatLiteral(_ raw: String) -> Float? {
	Float(raw.trimmingCharacters(in: .whitespacesAndNewlines))
}

private func parseUSDDoubleLiteral(_ raw: String) -> Double? {
	Double(raw.trimmingCharacters(in: .whitespacesAndNewlines))
}

private func parseUSDQuotedStringLiteral(_ raw: String) -> String {
	let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
	guard trimmed.count >= 2, trimmed.first == "\"", trimmed.last == "\"" else {
		return trimmed
	}
	let start = trimmed.index(after: trimmed.startIndex)
	let end = trimmed.index(before: trimmed.endIndex)
	let inner = String(trimmed[start..<end])
	return inner
		.replacingOccurrences(of: "\\\"", with: "\"")
		.replacingOccurrences(of: "\\\\", with: "\\")
}

private func parseUSDAssetLiteral(_ raw: String) -> String? {
	let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
	guard trimmed.count >= 2, trimmed.first == "@", trimmed.last == "@" else {
		return nil
	}
	let start = trimmed.index(after: trimmed.startIndex)
	let end = trimmed.index(before: trimmed.endIndex)
	return String(trimmed[start..<end])
}

private func parseUSDFloatTuple(_ raw: String, count: Int) -> [Double]? {
	let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
	guard trimmed.hasPrefix("("), trimmed.hasSuffix(")"), trimmed.count >= 2 else {
		return nil
	}
	let body = String(trimmed.dropFirst().dropLast())
	let values = body
		.split(separator: ",", omittingEmptySubsequences: true)
		.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
		.compactMap(Double.init)
	guard values.count >= count else { return nil }
	return Array(values.prefix(count))
}

private struct ParsedPrimDeclaration {
	let indent: String
	let typeName: String?
	let primName: String
	let metadataText: String?
}

private func parsePrimDeclarationLine(_ line: String) -> ParsedPrimDeclaration? {
	let declarationRegex = /^(\s*)(def|over|class)\s+(?:([A-Za-z0-9_:]+)\s+)?\"([^\"]+)\"(?:\s*\(([^)]*)\))?/
	guard let match = line.firstMatch(of: declarationRegex) else {
		return nil
	}
	let indent = String(match.output.1)
	let typeName = match.output.3.map(String.init)
	let primName = String(match.output.4)
	let metadataText = match.output.5.map(String.init)
	return ParsedPrimDeclaration(
		indent: indent,
		typeName: typeName,
		primName: primName,
		metadataText: metadataText
	)
}

private func parseRealityKitComponentPrimsFromUSDA(
	source: String,
	parentPrimPath: String
) -> [RealityKitComponentPrimInfo] {
	let lines = source.split(whereSeparator: \.isNewline).map(String.init)
	var stack: [USDAPrimContext] = []
	var pending: USDAPrimContext?
	var components: [RealityKitComponentPrimInfo] = []
	var componentIndexByPath: [String: Int] = [:]
	var pendingComponentPath: String?

	for line in lines {
		if let declaration = parsePrimDeclarationLine(line) {
			let parentPath = stack.last?.path
			let path = if let parent = stack.last?.path {
				"\(parent)/\(declaration.primName)"
			} else {
				"/\(declaration.primName)"
			}
			let context = USDAPrimContext(path: path, indent: declaration.indent)
			if line.contains("{") {
				stack.append(context)
			} else {
				pending = context
			}

			let isComponentType = declaration.typeName == "RealityKitComponent"
				|| declaration.typeName == "RealityKitCustomComponent"
			if isComponentType, parentPath == parentPrimPath {
				let info = RealityKitComponentPrimInfo(
					path: path,
					primName: declaration.primName,
					typeName: declaration.typeName ?? "Unknown",
					isActive: parseActiveFlag(from: declaration.metadataText) ?? true
				)
				components.append(info)
				componentIndexByPath[path] = components.count - 1
				pendingComponentPath = path
			} else {
				pendingComponentPath = nil
			}
		}

		if let componentPath = pendingComponentPath,
		   let index = componentIndexByPath[componentPath],
		   let parsedActive = parseActiveFlag(from: line)
		{
			components[index].isActive = parsedActive
		}

		if line.contains("{"), let pendingContext = pending {
			stack.append(pendingContext)
			pending = nil
			pendingComponentPath = nil
		}

		let closingCount = line.filter { $0 == "}" }.count
		if closingCount > 0 {
			for _ in 0..<closingCount {
				_ = stack.popLast()
			}
			pendingComponentPath = nil
		}
	}

	return components
}

private func parseComponentCustomDataAssetFromUSDA(
	source: String,
	componentPrimPath: String,
	key: String
) -> String? {
	let lines = source.split(whereSeparator: \.isNewline).map(String.init)
	var stack: [USDAPrimContext] = []
	var pending: USDAPrimContext?

	for (index, line) in lines.enumerated() {
		if let declaration = parsePrimDeclarationLine(line) {
			let path = if let parent = stack.last?.path {
				"\(parent)/\(declaration.primName)"
			} else {
				"/\(declaration.primName)"
			}
			let context = USDAPrimContext(path: path, indent: declaration.indent)
			if line.contains("{") {
				stack.append(context)
			} else {
				pending = context
			}

			if path == componentPrimPath,
			   let metadata = parseComponentMetadataBlock(lines: lines, declarationIndex: index)
			{
				return parseCustomDataAsset(in: metadata, key: key)
			}
		}

		if line.contains("{"), let pendingContext = pending {
			stack.append(pendingContext)
			pending = nil
		}

		let closingCount = line.filter { $0 == "}" }.count
		if closingCount > 0 {
			for _ in 0..<closingCount {
				_ = stack.popLast()
			}
		}
	}

	return nil
}

private func parseComponentMetadataBlock(
	lines: [String],
	declarationIndex: Int
) -> String? {
	guard declarationIndex < lines.count else { return nil }
	let declarationLine = lines[declarationIndex]
	guard let openIndex = declarationLine.firstIndex(of: "(") else {
		return nil
	}
	var metadata = String(declarationLine[declarationLine.index(after: openIndex)...])
	var depth = metadata.filter { $0 == "(" }.count - metadata.filter { $0 == ")" }.count
	if depth <= 0 {
		return metadata
	}
	var cursor = declarationIndex + 1
	while cursor < lines.count {
		let line = lines[cursor]
		metadata.append("\n")
		metadata.append(line)
		depth += line.filter { $0 == "(" }.count
		depth -= line.filter { $0 == ")" }.count
		if depth <= 0 {
			return metadata
		}
		cursor += 1
	}
	return metadata
}

private func parseCustomDataAsset(in metadata: String, key: String) -> String? {
	let escapedKey = NSRegularExpression.escapedPattern(for: key)
	let pattern = "asset\\s+\(escapedKey)\\s*=\\s*@([^@]+)@"
	guard let regex = try? NSRegularExpression(pattern: pattern) else {
		return nil
	}
	let nsRange = NSRange(metadata.startIndex..<metadata.endIndex, in: metadata)
	guard let match = regex.firstMatch(in: metadata, options: [], range: nsRange),
		  let valueRange = Range(match.range(at: 1), in: metadata)
	else {
		return nil
	}
	return String(metadata[valueRange])
}

private func parseActiveFlag(from text: String?) -> Bool? {
	guard let text else { return nil }
	let normalized = text.replacingOccurrences(of: "\t", with: " ")
	if normalized.range(of: "active\\s*=\\s*false", options: .regularExpression) != nil {
		return false
	}
	if normalized.range(of: "active\\s*=\\s*true", options: .regularExpression) != nil {
		return true
	}
	return nil
}

private func updateRealityKitComponentParameterInUSDA(
	_ source: String,
	componentPrimPath: String,
	attributeType: String,
	attributeName: String,
	valueLiteral: String
) throws -> String {
	let lines = source.split(whereSeparator: \.isNewline).map(String.init)
	let indentUnit = source.contains("\t") ? "\t" : "    "
	let attrRegex = try NSRegularExpression(
		pattern: #"^\s*(?:uniform\s+)?[A-Za-z0-9_:\[\]]+\s+([A-Za-z_][A-Za-z0-9_:]*)\s*="#
	)

	var stack: [USDAPrimContext] = []
	var pending: USDAPrimContext?
	var componentIndent: String?
	var inTarget = false
	var insertIndex: Int?
	var replaceIndex: Int?

	for (index, line) in lines.enumerated() {
		if let declaration = parsePrimDeclarationLine(line) {
			let path = if let parent = stack.last?.path {
				"\(parent)/\(declaration.primName)"
			} else {
				"/\(declaration.primName)"
			}
			let context = USDAPrimContext(path: path, indent: declaration.indent)
			if line.contains("{") {
				stack.append(context)
				inTarget = context.path == componentPrimPath
				if inTarget { componentIndent = context.indent }
			} else {
				pending = context
			}
		}

		if line.contains("{"), let pendingContext = pending {
			stack.append(pendingContext)
			inTarget = pendingContext.path == componentPrimPath
			if inTarget { componentIndent = pendingContext.indent }
			pending = nil
		}

		if inTarget {
			let nsLine = line as NSString
			let range = NSRange(location: 0, length: nsLine.length)
			if let match = attrRegex.firstMatch(in: line, options: [], range: range),
			   match.numberOfRanges > 1
			{
				let nameRange = match.range(at: 1)
				if nameRange.location != NSNotFound {
					let name = nsLine.substring(with: nameRange)
					if name == attributeName {
						replaceIndex = index
					}
				}
			}
		}

		let closingCount = line.filter { $0 == "}" }.count
		if closingCount > 0 {
			for _ in 0..<closingCount {
				guard let current = stack.last else { break }
				if current.path == componentPrimPath && insertIndex == nil {
					insertIndex = index
				}
				_ = stack.popLast()
				inTarget = stack.last?.path == componentPrimPath
			}
		}
	}

	guard let componentIndent, let insertIndex else {
		throw DeconstructedUSDInteropError.componentAuthoringFailed(
			reason: "Component prim not found: \(componentPrimPath)"
		)
	}

	let fieldIndent = componentIndent + indentUnit
	let authoredLine = "\(fieldIndent)\(attributeType) \(attributeName) = \(valueLiteral)"
	var updatedLines = lines
	if let replaceIndex {
		updatedLines[replaceIndex] = authoredLine
	} else {
		updatedLines.insert(authoredLine, at: insertIndex)
	}

	let updated = updatedLines.joined(separator: "\n")
	return source.hasSuffix("\n") ? updated + "\n" : updated
}

private func removeRealityKitComponentParameterInUSDA(
	_ source: String,
	componentPrimPath: String,
	attributeName: String
) throws -> String {
	let lines = source.split(whereSeparator: \.isNewline).map(String.init)
	let attrRegex = try NSRegularExpression(
		pattern: #"^\s*(?:uniform\s+)?[A-Za-z0-9_:\[\]]+\s+([A-Za-z_][A-Za-z0-9_:]*)\s*="#
	)

	var stack: [USDAPrimContext] = []
	var pending: USDAPrimContext?
	var inTarget = false
	var removeIndex: Int?

	for (index, line) in lines.enumerated() {
		if let declaration = parsePrimDeclarationLine(line) {
			let path = if let parent = stack.last?.path {
				"\(parent)/\(declaration.primName)"
			} else {
				"/\(declaration.primName)"
			}
			let context = USDAPrimContext(path: path, indent: declaration.indent)
			if line.contains("{") {
				stack.append(context)
				inTarget = context.path == componentPrimPath
			} else {
				pending = context
			}
		}

		if line.contains("{"), let pendingContext = pending {
			stack.append(pendingContext)
			inTarget = pendingContext.path == componentPrimPath
			pending = nil
		}

		if inTarget {
			let nsLine = line as NSString
			let range = NSRange(location: 0, length: nsLine.length)
			if let match = attrRegex.firstMatch(in: line, options: [], range: range),
			   match.numberOfRanges > 1
			{
				let nameRange = match.range(at: 1)
				if nameRange.location != NSNotFound {
					let name = nsLine.substring(with: nameRange)
					if name == attributeName {
						removeIndex = index
						break
					}
				}
			}
		}

		let closingCount = line.filter { $0 == "}" }.count
		if closingCount > 0 {
			for _ in 0..<closingCount {
				_ = stack.popLast()
				inTarget = stack.last?.path == componentPrimPath
			}
		}
	}

	guard let removeIndex else {
		return source
	}
	var updatedLines = lines
	updatedLines.remove(at: removeIndex)
	let updated = updatedLines.joined(separator: "\n")
	return source.hasSuffix("\n") ? updated + "\n" : updated
}

private func insertTypedPrimInUSDA(
	_ source: String,
	parentPrimPath: String,
	typeName: String,
	primName: String
) throws -> String {
	let lines = source.split(whereSeparator: \.isNewline).map(String.init)
	let indentUnit = source.contains("\t") ? "\t" : "    "
	var stack: [USDAPrimContext] = []
	var pending: USDAPrimContext?
	var insertionLineIndex: Int?
	var parentIndent: String?
	var existingPrimPath: String?

	for (index, line) in lines.enumerated() {
		if let declaration = parsePrimDeclarationLine(line) {
			let path = if let parent = stack.last?.path {
				"\(parent)/\(declaration.primName)"
			} else {
				"/\(declaration.primName)"
			}
			if path == "\(parentPrimPath)/\(primName)" {
				existingPrimPath = path
			}
			let context = USDAPrimContext(path: path, indent: declaration.indent)
			if line.contains("{") {
				stack.append(context)
				if context.path == parentPrimPath {
					parentIndent = context.indent
				}
			} else {
				pending = context
			}
		}
		if line.contains("{"), let pendingContext = pending {
			stack.append(pendingContext)
			if pendingContext.path == parentPrimPath {
				parentIndent = pendingContext.indent
			}
			pending = nil
		}
		let closingCount = line.filter { $0 == "}" }.count
		if closingCount > 0 {
			for _ in 0..<closingCount {
				guard let current = stack.last else { break }
				if current.path == parentPrimPath && insertionLineIndex == nil {
					insertionLineIndex = index
				}
				_ = stack.popLast()
			}
		}
	}

	if existingPrimPath != nil {
		return source
	}

	guard let insertionLineIndex, let parentIndent else {
		throw DeconstructedUSDInteropError.componentAuthoringFailed(
			reason: "Parent prim not found for insertion: \(parentPrimPath)"
		)
	}

	let childIndent = parentIndent + indentUnit
	let block: [String] = [
		"",
		"\(childIndent)def \(typeName) \"\(primName)\" (",
		"\(childIndent)\(indentUnit)active = true",
		"\(childIndent))",
		"\(childIndent){",
		"\(childIndent)}"
	]

	var updatedLines = lines
	updatedLines.insert(contentsOf: block, at: insertionLineIndex)
	let updated = updatedLines.joined(separator: "\n")
	return source.hasSuffix("\n") ? updated + "\n" : updated
}

private func parentPath(of primPath: String) -> String? {
	let trimmed = primPath.trimmingCharacters(in: .whitespacesAndNewlines)
	guard trimmed.hasPrefix("/"), trimmed.count > 1 else { return nil }
	let parts = trimmed.split(separator: "/").map(String.init)
	guard parts.count > 1 else { return nil }
	return "/" + parts.dropLast().joined(separator: "/")
}

private func primName(of primPath: String) -> String? {
	let trimmed = primPath.trimmingCharacters(in: .whitespacesAndNewlines)
	guard trimmed.hasPrefix("/"), trimmed.count > 1 else { return nil }
	return trimmed.split(separator: "/").last.map(String.init)
}
