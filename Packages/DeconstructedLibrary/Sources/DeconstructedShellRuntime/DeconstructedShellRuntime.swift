import DeconstructedUSDInterop
import Foundation
import InspectorFeature
import SwiftUsdShell
import USDInterfaces
import USDOperations

/// Runtime boundary for SwiftUsdShell value types.
///
/// Bridges the OpenUSD-backed `USDOperationsClient` to the pure-Swift
/// `SwiftUsdShell` DTOs that downstream app/feature/UI targets consume. App
/// modules depend on this target (or the protocols feature modules expose),
/// not on `USDOperations` directly, so the OpenUSD compile cost is paid here
/// once and not at every consumer.
///
/// 1. Opening stages and producing USDStageHandle
/// 2. Producing SwiftUsdShell.USDPrimSummary values
/// 3. Building prim trees in SwiftUsdShell.USDPrimTree format
/// 4. Converting stage metadata to SwiftUsdShell.USDStageMetadata
///
/// Some operations still use a lightweight USDA text reader as a stopgap for
/// validation tests; production paths should call into USDOperationsClient.
public enum DeconstructedShellRuntime {

	// MARK: - Stage Lifecycle

	/// Opens a USD stage and returns a handle for it.
	///
	/// The stage is kept alive in the runtime's internal cache. Callers
	/// receive a USDStageHandle which is a stable identifier for the stage.
	///
	/// - Parameter url: The URL of the USD file to open
	/// - Returns: A handle to the opened stage
	/// - Throws: If the stage cannot be opened
	public static func openStage(at url: URL) throws -> USDStageHandle {
		guard FileManager.default.fileExists(atPath: url.path),
		      (try? String(contentsOf: url, encoding: .utf8)) != nil
		else {
			throw ShellRuntimeError.stageOpenFailed(url)
		}
		let handle = USDStageHandle(rawValue: stageCache.register(url))
		return handle
	}

	/// Closes a stage and releases its resources.
	///
	/// After closing, the handle becomes invalid. Subsequent operations
	/// with this handle will fail.
	///
	/// - Parameter handle: The handle to the stage to close
	public static func closeStage(_ handle: USDStageHandle) {
		stageCache.unregister(handle.rawValue)
	}

	// MARK: - Prim Summaries

	/// Returns a summary of a prim's metadata and attributes.
	///
	/// This is the primary query surface for inspector UIs. It provides
	/// a pure Swift representation of prim data.
	///
	/// - Parameters:
	///   - url: The URL of the USD file
	///   - primPath: The path to the prim
	/// - Returns: A summary of the prim, or nil if the prim doesn't exist
	public static func primSummary(url: URL, primPath: String) -> SwiftUsdShell.USDPrimSummary? {
		guard let raw = USDOperationsClient().primAttributes(url: url, path: primPath) else {
			return nil
		}

		let attributeSummaries = raw.authoredAttributes.map { attr -> SwiftUsdShell.USDAttributeSummary in
			SwiftUsdShell.USDAttributeSummary(
				name: SwiftUsdShell.USDToken(attr.name),
				typeName: "",
				value: parseUSDAttributeValue(attr.value),
				isAuthored: true,
				hasValue: !attr.value.isEmpty && attr.value != "(authored)",
				timeSampleCount: 0,
				timeSamples: [.default]
			)
		}

		return SwiftUsdShell.USDPrimSummary(
			path: SwiftUsdShell.USDPath(raw.primPath),
			name: SwiftUsdShell.USDToken(raw.primName),
			typeName: raw.typeName.isEmpty ? nil : SwiftUsdShell.USDToken(raw.typeName),
			isActive: raw.isActive,
			visibility: raw.visibility.isEmpty ? nil : SwiftUsdShell.USDToken(raw.visibility),
			purpose: raw.purpose.isEmpty ? nil : SwiftUsdShell.USDToken(raw.purpose),
			kind: raw.kind.isEmpty ? nil : SwiftUsdShell.USDToken(raw.kind),
			attributes: attributeSummaries,
			relationships: []
		)
	}

	// MARK: - Prim Tree

	/// Builds a prim tree representation of the stage.
	///
	/// This is useful for scene graph UIs that need a hierarchical view
	/// of all prims in the stage.
	///
	/// - Parameter url: The URL of the USD file
	/// - Returns: A tree structure representing the prim hierarchy
	public static func primTree(url: URL) -> SwiftUsdShell.USDPrimTree {
		guard let stage = parseStage(url: url) else {
			return SwiftUsdShell.USDPrimTree(path: "/", name: "", children: [])
		}

		return SwiftUsdShell.USDPrimTree(
			path: "/",
			name: "",
			children: stage.rootPrims.map(buildPrimTreeNode(from:))
		)
	}

	// MARK: - Stage Metadata

	/// Returns metadata about the stage.
	///
	/// Reads `upAxis`, `metersPerUnit`, `defaultPrim`, playback/animation
	/// fields, and the camera list via `USDOperationsClient` and maps the
	/// USDInterfaces DTO onto the pure-Swift SwiftUsdShell shape so callers
	/// never see the C++-backed types.
	///
	/// - Parameter url: The URL of the USD file
	/// - Returns: The stage metadata
	public static func stageMetadata(url: URL) -> SwiftUsdShell.USDStageMetadata {
		let raw = USDOperationsClient().stageMetadata(url: url)
		return SwiftUsdShell.USDStageMetadata(
			upAxis: raw.upAxis.map { SwiftUsdShell.USDToken($0) },
			metersPerUnit: raw.metersPerUnit,
			defaultPrimName: raw.defaultPrimName.map { SwiftUsdShell.USDToken($0) },
			autoPlay: raw.autoPlay,
			playbackMode: raw.playbackMode,
			timeCodesPerSecond: raw.timeCodesPerSecond,
			startTimeCode: raw.startTimeCode,
			endTimeCode: raw.endTimeCode,
			animationTracks: raw.animationTracks.map { SwiftUsdShell.USDPath($0) },
			availableCameras: raw.availableCameras.map { SwiftUsdShell.USDPath($0) }
		)
	}

	// MARK: - Prim Transform

	/// Returns the local transform (position / Euler rotation in degrees /
	/// scale) for a prim, bridged onto the SwiftUsdShell DTO so callers do
	/// not see the C++-backed USDInterfaces type.
	///
	/// Returns `nil` when the prim is missing, the stage cannot be opened,
	/// or the prim is not transformable.
	///
	/// - Parameters:
	///   - url: The URL of the USD file
	///   - primPath: The path to the prim
	public static func primTransform(url: URL, primPath: String) -> SwiftUsdShell.USDTransformData? {
		guard let raw = USDOperationsClient().primTransform(url: url, path: primPath) else {
			return nil
		}
		return SwiftUsdShell.USDTransformData(
			position: raw.position,
			rotationDegrees: raw.rotationDegrees,
			orientation: nil,
			scale: raw.scale
		)
	}

	// MARK: - Scene Materials

	/// Returns the list of `Material` prims authored on the stage, mapped to
	/// the pure-Swift `SwiftUsdShell.USDMaterialSummary` DTO.
	public static func allMaterials(url: URL) -> [SwiftUsdShell.USDMaterialSummary] {
		USDOperationsClient().allMaterials(url: url).map { info in
			SwiftUsdShell.USDMaterialSummary(
				path: SwiftUsdShell.USDPath(info.path),
				name: info.name,
				materialType: bridgeMaterialSummaryType(info.materialType)
			)
		}
	}

	private static func bridgeMaterialSummaryType(
		_ raw: USDInterfaces.USDMaterialInfo.MaterialType
	) -> SwiftUsdShell.USDMaterialSummaryType {
		switch raw {
		case .previewSurface: return .usdPreviewSurface
		case .materialX: return .materialX
		case .unknown: return .unknown
		@unknown default: return .unknown
		}
	}

	// MARK: - Material Properties

	/// Returns the material's authored attributes plus the authored
	/// attributes of every Shader-style child prim under it, so the
	/// inspector surfaces inputs:diffuseColor / metallic / roughness etc.
	/// for a typical UsdPreviewSurface / MaterialX network.
	///
	/// Implementation: USDA-text walk via `DeconstructedUSDInterop.listChildPrims`
	/// to enumerate immediate children (open-source path, no OpenUSDKit
	/// dependency), then `USDOperationsClient.primAttributes` on each child.
	/// Each property is prefixed with the shader prim name so multi-shader
	/// networks stay disambiguated.
	public static func materialProperties(
		url: URL, materialPath: String
	) -> [SwiftUsdShell.USDMaterialPropertySummary] {
		let client = USDOperationsClient()
		var summaries: [SwiftUsdShell.USDMaterialPropertySummary] = []

		if let materialAttrs = client.primAttributes(url: url, path: materialPath) {
			for attr in materialAttrs.authoredAttributes {
				summaries.append(
					SwiftUsdShell.USDMaterialPropertySummary(
						name: attr.name,
						propertyType: .unsupported,
						value: .unsupported(typeName: "", valueDescription: attr.value)
					)
				)
			}
		}

		let children = DeconstructedUSDInterop.listChildPrims(url: url, parentPrimPath: materialPath)
		for child in children {
			guard let shaderAttrs = client.primAttributes(url: url, path: child.path) else {
				continue
			}
			for attr in shaderAttrs.authoredAttributes {
				summaries.append(
					SwiftUsdShell.USDMaterialPropertySummary(
						name: "\(child.primName).\(attr.name)",
						propertyType: .unsupported,
						value: .unsupported(typeName: child.typeName ?? "", valueDescription: attr.value)
					)
				)
			}
		}

		return summaries
	}

	// MARK: - Material Binding

	/// Returns the effective material binding for a prim, including
	/// authored / inherited paths and binding strength.
	///
	/// Returns `nil` when the stage cannot be opened.
	public static func materialBinding(url: URL, primPath: String) -> SwiftUsdShell.USDMaterialBindingInfo? {
		let raw = USDOperationsClient().materialBindingDetails(url: url, path: primPath)
		return SwiftUsdShell.USDMaterialBindingInfo(
			selectedPrimPath: SwiftUsdShell.USDPath(raw.selectedPrimPath),
			effectiveMaterialPath: raw.effectiveMaterialPath.map { SwiftUsdShell.USDPath($0) },
			authoredMaterialPath: raw.authoredMaterialPath.map { SwiftUsdShell.USDPath($0) },
			bindingSourcePrimPath: raw.bindingSourcePrimPath.map { SwiftUsdShell.USDPath($0) },
			bindingStrength: raw.bindingStrength.flatMap { SwiftUsdShell.USDMaterialBindingStrength(rawValue: $0.rawValue) }
		)
	}

	// MARK: - Prim References

	/// Returns the references composed onto a prim, mapped to the
	/// pure-Swift SwiftUsdShell DTO.
	public static func primReferences(url: URL, primPath: String) -> [SwiftUsdShell.USDReference] {
		USDOperationsClient().primReferences(url: url, path: primPath).map { ref in
			SwiftUsdShell.USDReference(assetPath: ref.assetPath, primPath: ref.primPath)
		}
	}

	// MARK: - Variant Sets

	/// Returns the variant sets authored on a prim, mapped to
	/// `SwiftUsdShell.USDVariantSetSummary`.
	public static func primVariantSets(url: URL, primPath: String) -> [SwiftUsdShell.USDVariantSetSummary] {
		let descriptors = (try? USDOperationsClient().listVariantSets(url: url, scope: .prim(path: primPath))) ?? []
		return descriptors.map { descriptor in
			SwiftUsdShell.USDVariantSetSummary(
				name: SwiftUsdShell.USDToken(descriptor.name),
				choices: descriptor.options.map { SwiftUsdShell.USDToken($0.id) },
				selection: descriptor.selectedOptionId.map { SwiftUsdShell.USDToken($0) },
				hasAuthoredSelection: descriptor.selectedOptionId != nil
			)
		}
	}

	// MARK: - Composition Arcs

	/// Returns the composition arcs that contributed opinions to a prim,
	/// derived from `USDOperationsClient.primProvenance` and mapped onto the
	/// pure-Swift `SwiftUsdShell.USDCompositionArcSummary`. The shell DTO
	/// only models reference vs payload; inherits/specializes/variant/local
	/// arcs collapse onto `.reference` with `isInternal = true` (lossy by
	/// design — refine when shell models the full enum).
	public static func primCompositionArcs(url: URL, primPath: String) -> [SwiftUsdShell.USDCompositionArcSummary] {
		guard let provenance = USDOperationsClient().primProvenance(url: url, path: primPath) else {
			return []
		}
		return provenance.sites.map { site -> SwiftUsdShell.USDCompositionArcSummary in
			let kind: SwiftUsdShell.USDCompositionArcKind = site.kind == .payload ? .payload : .reference
			let isInternal: Bool
			switch site.kind {
			case .reference, .payload: isInternal = false
			case .localLayer, .sublayer, .inherits, .specializes, .variant, .unknown: isInternal = true
			@unknown default: isInternal = true
			}
			let assetPath = site.layerRealPath ?? site.layerIdentifier
			return SwiftUsdShell.USDCompositionArcSummary(
				kind: kind,
				assetPath: SwiftUsdShell.USDAssetPath(assetPath),
				primPath: site.specPath.map { SwiftUsdShell.USDPath($0) },
				layerOffset: nil,
				isInternal: isInternal
			)
		}
	}

	// MARK: - Prim Components

	/// Returns the RealityKit component prims authored as children of the
	/// selected prim, each annotated with its authored attributes.
	///
	/// Rescued from the orphan inspector: delegates to
	/// `DeconstructedUSDInterop.listRealityKitComponentPrims` for the child
	/// listing and `getPrimAttributes` for each component's authored values.
	/// Results are pure-Swift `InspectorComponentSummary` values so consumers
	/// never see the USDInterfaces types.
	public static func primComponents(url: URL, primPath: String) -> [InspectorComponentSummary] {
		let infos = DeconstructedUSDInterop.listRealityKitComponentPrims(url: url, parentPrimPath: primPath)
		return infos.map { info -> InspectorComponentSummary in
			let attrs = DeconstructedUSDInterop.getPrimAttributes(url: url, primPath: info.path)?.authoredAttributes ?? []
			return InspectorComponentSummary(
				path: info.path,
				name: info.primName,
				typeName: info.typeName,
				isActive: info.isActive,
				authoredAttributes: attrs.map { InspectorAuthoredAttribute(name: $0.name, value: $0.value) }
			)
		}
	}

	// MARK: - Transform Write

	/// Writes a prim's local transform. Bridges the SwiftUsdShell
	/// `USDTransformData` (which carries an optional orientation quaternion
	/// the underlying operation does not author) onto the USDInterfaces
	/// shape via `DeconstructedUSDInterop.setPrimTransform`.
	public static func setPrimTransform(
		url: URL,
		primPath: String,
		transform: SwiftUsdShell.USDTransformData
	) throws {
		let raw = USDInterfaces.USDTransformData(
			position: transform.position,
			rotationDegrees: transform.rotationDegrees,
			scale: transform.scale
		)
		try DeconstructedUSDInterop.setPrimTransform(url: url, primPath: primPath, transform: raw)
	}

	// MARK: - Material Binding Write

	/// Binds a material to a prim or clears the binding when `materialPath`
	/// is `nil`. Delegates to `DeconstructedUSDInterop` so we reuse the
	/// edit-target plumbing already wired there.
	public static func setMaterialBinding(
		url: URL,
		primPath: String,
		materialPath: String?
	) throws {
		if let materialPath {
			try DeconstructedUSDInterop.setMaterialBinding(url: url, primPath: primPath, materialPath: materialPath)
		} else {
			try DeconstructedUSDInterop.clearMaterialBinding(url: url, primPath: primPath)
		}
	}

	public static func setMaterialBindingStrength(
		url: URL,
		primPath: String,
		strength: SwiftUsdShell.USDMaterialBindingStrength
	) throws {
		let raw = bridgeBindingStrengthOut(strength)
		try DeconstructedUSDInterop.setMaterialBindingStrength(url: url, primPath: primPath, strength: raw)
	}

	private static func bridgeBindingStrengthOut(
		_ shell: SwiftUsdShell.USDMaterialBindingStrength
	) -> USDInterfaces.USDMaterialBindingStrength {
		USDInterfaces.USDMaterialBindingStrength(rawValue: shell.rawValue) ?? .fallbackStrength
	}

	// MARK: - Variant Selection Write

	public static func setPrimVariantSelection(
		url: URL,
		primPath: String,
		setName: String,
		selectionId: String?
	) throws {
		try DeconstructedUSDInterop.setPrimVariantSelection(
			url: url,
			primPath: primPath,
			setName: setName,
			selectionId: selectionId
		)
	}

	// MARK: - Component Writes

	public static func setComponentActive(
		url: URL,
		componentPath: String,
		isActive: Bool
	) throws {
		try DeconstructedUSDInterop.setRealityKitComponentActive(
			url: url,
			componentPrimPath: componentPath,
			isActive: isActive
		)
	}

	public static func deleteComponent(url: URL, componentPath: String) throws {
		try DeconstructedUSDInterop.deleteRealityKitComponent(
			url: url,
			componentPrimPath: componentPath
		)
	}

	// MARK: - Reference Writes

	public static func addPrimReference(
		url: URL,
		primPath: String,
		reference: SwiftUsdShell.USDReference
	) throws {
		try DeconstructedUSDInterop.addPrimReference(
			url: url,
			primPath: primPath,
			reference: USDInterfaces.USDReference(assetPath: reference.assetPath, primPath: reference.primPath)
		)
	}

	public static func removePrimReference(
		url: URL,
		primPath: String,
		reference: SwiftUsdShell.USDReference
	) throws {
		try DeconstructedUSDInterop.removePrimReference(
			url: url,
			primPath: primPath,
			reference: USDInterfaces.USDReference(assetPath: reference.assetPath, primPath: reference.primPath)
		)
	}

	// MARK: - Stage Metadata Writes

	public static func setDefaultPrim(url: URL, primPath: String) throws {
		try DeconstructedUSDInterop.setDefaultPrim(url: url, primPath: primPath)
	}

	public static func setMetersPerUnit(url: URL, value: Double) throws {
		try DeconstructedUSDInterop.setMetersPerUnit(url: url, value: value)
	}

	public static func setUpAxis(url: URL, axis: String) throws {
		try DeconstructedUSDInterop.setUpAxis(url: url, axis: axis)
	}

	// MARK: - Component Parameter Writes

	public static func setComponentParameter(
		url: URL,
		componentPath: String,
		attributeType: String,
		attributeName: String,
		valueLiteral: String
	) throws {
		try DeconstructedUSDInterop.setRealityKitComponentParameter(
			url: url,
			componentPrimPath: componentPath,
			attributeType: attributeType,
			attributeName: attributeName,
			valueLiteral: valueLiteral
		)
	}

	@discardableResult
	public static func addComponent(
		url: URL,
		primPath: String,
		componentName: String,
		componentIdentifier: String
	) throws -> String {
		try DeconstructedUSDInterop.addRealityKitComponent(
			url: url,
			primPath: primPath,
			componentName: componentName,
			componentIdentifier: componentIdentifier
		)
	}

	// MARK: - Material Edits

	/// Executes a material edit request.
	///
	/// `SwiftUsdShell` 0.3.x intentionally models the stable request/result
	/// contract only. Planning policy such as branch analysis and conversion
	/// strategy belongs in this runtime or the application layer.
	///
	/// - Parameter request: The edit to execute
	/// - Returns: The result of the edit
	/// - Throws: If the edit cannot be executed
	public static func executeMaterialEdit(request: SwiftUsdShell.USDMaterialEditRequest) throws -> SwiftUsdShell.USDMaterialEditResult {
		switch request.operation {
		case .setTexture:
			// For now, we only support basic texture setting
			// A full implementation would need to handle:
			// - Material surface output detection
			// - Asset path resolution
			// - Layer editing
			throw ShellRuntimeError.notImplemented("Texture setting not yet implemented")

		case .clearTexture:
			throw ShellRuntimeError.notImplemented("Texture clearing not yet implemented")

		case .setValue:
			throw ShellRuntimeError.notImplemented("Value setting not yet implemented")

		case .clearValue:
			throw ShellRuntimeError.notImplemented("Value clearing not yet implemented")
		}
	}

	// MARK: - Private Helpers

	private static let stageCache = StageHandleCache()

	private static func parseUSDAttributeValue(_ value: String) -> SwiftUsdShell.USDValue? {
		// Try to parse the value string into appropriate types
		if let boolValue = parseBool(from: value) {
			return .bool(boolValue)
		} else if let intValue = parseInt(from: value) {
			return .int(intValue)
		} else if let doubleValue = parseDouble(from: value) {
			return .double(doubleValue)
		} else if let arrayValues = parseArray(from: value) {
			return .array(arrayValues)
		} else if let vector3 = parseVector3(from: value) {
			return .vector3(SwiftUsdShell.USDVector3(x: vector3.x, y: vector3.y, z: vector3.z))
		} else if value.contains("@") && value.count > 2 {
			// Asset path: @path@
			let inner = value.dropFirst().dropLast()
			return .assetPath(SwiftUsdShell.USDAssetPath(String(inner)))
		} else if value.starts(with: "<") && value.hasSuffix(">") {
			// Relationship target
			let inner = value.dropFirst().dropLast()
			return .string(String(inner))
		}

		// Default to string
		return .string(value)
	}

	private static func inferTypeName(from value: String) -> String {
		if value.contains("GfVec3d") || value.contains("GfVec3f") || parseVector3(from: value) != nil {
			return "float3"
		} else if value.contains("GfVec2d") || value.contains("GfVec2f") {
			return "float2"
		} else if parseBool(from: value) != nil {
			return "bool"
		} else if parseInt(from: value) != nil {
			return "int"
		} else if parseDouble(from: value) != nil && !value.contains(".") {
			return "float"
		} else if value.contains("[") && value.contains("]") {
			return "array"
		} else if value.contains("@") {
			return "asset"
		}
		return "string"
	}

	private static func parseBool(from value: String) -> Bool? {
		let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
		if trimmed == "true" || trimmed == "1" {
			return true
		} else if trimmed == "false" || trimmed == "0" {
			return false
		}
		return nil
	}

	private static func parseInt(from value: String) -> Int64? {
		let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
			.replacingOccurrences(of: "GfVec3d", with: "")
			.replacingOccurrences(of: "GfVec3f", with: "")
			.replacingOccurrences(of: "(", with: "")
			.replacingOccurrences(of: ")", with: "")
			.replacingOccurrences(of: "[", with: "")
			.replacingOccurrences(of: "]", with: "")
		return Int64(trimmed)
	}

	private static func parseDouble(from value: String) -> Double? {
		let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
		return Double(trimmed)
	}

	private static func parseVector3(from value: String) -> (x: Double, y: Double, z: Double)? {
		let pattern = #"[0-9.-]+"#
		guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }

		let nsRange = NSRange(value.startIndex..<value.endIndex, in: value)
		let matches = regex.matches(in: value, options: [], range: nsRange)

		let numbers = matches.compactMap { match -> Double? in
			guard let range = Range(match.range, in: value) else { return nil }
			return Double(String(value[range]))
		}

		guard numbers.count >= 3 else { return nil }
		return (x: numbers[0], y: numbers[1], z: numbers[2])
	}

	private static func parseArray(from value: String) -> [SwiftUsdShell.USDValue]? {
		guard value.hasPrefix("[") && value.hasSuffix("]") else { return nil }

		let inner = String(value.dropFirst().dropLast())
		let trimmed = inner.trimmingCharacters(in: .whitespacesAndNewlines)

		guard !trimmed.isEmpty else { return [] }

		if trimmed.contains("("), trimmed.contains(")") {
			let pattern = #"\([^)]+\)"#
			guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
			let nsRange = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
			return regex.matches(in: trimmed, range: nsRange).compactMap { match in
				guard let range = Range(match.range, in: trimmed),
				      let vector = parseVector3(from: String(trimmed[range]))
				else { return nil }
				return .vector3(SwiftUsdShell.USDVector3(x: vector.x, y: vector.y, z: vector.z))
			}
		}

		let elements = trimmed.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

		if parseBool(from: elements[0]) != nil {
			return elements.map { .bool(parseBool(from: $0) ?? false) }
		} else if parseDouble(from: elements[0]) != nil {
			return elements.map { .double(parseDouble(from: $0) ?? 0) }
		}

		return elements.map { .string($0) }
	}

	private static func buildPrimTreeNode(from node: ParsedPrim) -> SwiftUsdShell.USDPrimTree {
		return SwiftUsdShell.USDPrimTree(
			path: SwiftUsdShell.USDPath(node.path),
			name: SwiftUsdShell.USDToken(node.name),
			typeName: node.typeName.isEmpty ? nil : SwiftUsdShell.USDToken(node.typeName),
			purpose: node.purpose.isEmpty ? nil : SwiftUsdShell.USDToken(node.purpose),
			children: node.children.map(buildPrimTreeNode(from:))
		)
	}

	private static func parseStage(url: URL) -> ParsedStage? {
		guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }

		var metadata = ParsedStageMetadata()
		metadata.defaultPrimName = firstCapture(in: text, pattern: #"defaultPrim\s*=\s*"([^"]+)""#)
		metadata.upAxis = firstCapture(in: text, pattern: #"upAxis\s*=\s*"([^"]+)""#)
		if let meters = firstCapture(in: text, pattern: #"metersPerUnit\s*=\s*([0-9.]+)"#) {
			metadata.metersPerUnit = Double(meters)
		}

		let lines = text.components(separatedBy: .newlines)
		var rootPrims: [ParsedPrim] = []
		var stack: [ParsedPrim] = []

		for rawLine in lines {
			let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
			if line.isEmpty || line.hasPrefix("#") || line == "(" || line == ")" {
				continue
			}

			if let declaration = parsePrimDeclaration(line) {
				let parentPath = stack.last?.path ?? ""
				let path = parentPath.isEmpty ? "/\(declaration.name)" : "\(parentPath)/\(declaration.name)"
				stack.append(
					ParsedPrim(
						path: path,
						name: declaration.name,
						typeName: declaration.typeName,
						visibility: declaration.typeName == "Cube" ? "visible" : "",
						purpose: "default",
						isActive: true
					)
				)
				continue
			}

			if line == "}" || line == "}," {
				guard let prim = stack.popLast() else { continue }
				if stack.isEmpty {
					rootPrims.append(prim)
				} else {
					stack[stack.count - 1].children.append(prim)
				}
				continue
			}

			guard stack.isEmpty == false,
			      let attribute = parseAttribute(line)
			else { continue }

			stack[stack.count - 1].attributes.append(attribute)
			switch attribute.name {
			case "active":
				stack[stack.count - 1].isActive = parseBool(from: attribute.value) ?? true
			case "visibility":
				stack[stack.count - 1].visibility = unquoted(attribute.value)
			case "purpose":
				stack[stack.count - 1].purpose = unquoted(attribute.value)
			case "kind":
				stack[stack.count - 1].kind = unquoted(attribute.value)
			default:
				break
			}
		}

		while let prim = stack.popLast() {
			if stack.isEmpty {
				rootPrims.append(prim)
			} else {
				stack[stack.count - 1].children.append(prim)
			}
		}

		return ParsedStage(metadata: metadata, rootPrims: rootPrims)
	}

	private static func parsePrimDeclaration(_ line: String) -> (typeName: String, name: String)? {
		guard let match = firstMatch(in: line, pattern: #"def\s+([A-Za-z_][A-Za-z0-9_]*)\s+"([^"]+)""#),
		      match.count == 3
		else { return nil }
		return (match[1], match[2])
	}

	private static func parseAttribute(_ line: String) -> ParsedAttribute? {
		guard line.contains("="), !line.hasPrefix("prepend ") else { return nil }
		let parts = line.split(separator: "=", maxSplits: 1).map(String.init)
		guard parts.count == 2 else { return nil }

		let left = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
		let value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
		let tokens = left.split(separator: " ").map(String.init)
		guard let name = tokens.last else { return nil }
		let typeName = tokens.dropLast().joined(separator: " ")
		return ParsedAttribute(name: name, typeName: typeName, value: value)
	}

	private static func firstCapture(in text: String, pattern: String) -> String? {
		firstMatch(in: text, pattern: pattern)?.dropFirst().first
	}

	private static func firstMatch(in text: String, pattern: String) -> [String]? {
		guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
		let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
		guard let match = regex.firstMatch(in: text, range: nsRange) else { return nil }
		return (0..<match.numberOfRanges).compactMap { index in
			guard let range = Range(match.range(at: index), in: text) else { return nil }
			return String(text[range])
		}
	}

	private static func unquoted(_ value: String) -> String {
		value.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
	}
}

// MARK: - Errors

public enum ShellRuntimeError: Error, LocalizedError {
	case stageOpenFailed(URL)
	case invalidHandle(USDStageHandle)
	case notImplemented(String)

	public var errorDescription: String? {
		switch self {
		case let .stageOpenFailed(url):
			return "Failed to open USD stage at \(url.path)"
		case let .invalidHandle(handle):
			return "Invalid stage handle: \(handle.rawValue)"
		case let .notImplemented(feature):
			return "Not implemented: \(feature)"
		}
	}
}

// MARK: - Stage Handle Cache

private final class StageHandleCache: @unchecked Sendable {
	private var cache: [UInt64: URL] = [:]
	private var nextHandle: UInt64 = 1
	private let lock = NSLock()

	func register(_ url: URL) -> UInt64 {
		lock.lock()
		defer { lock.unlock() }
		let handle = nextHandle
		nextHandle &+= 1
		cache[handle] = url
		return handle
	}

	func unregister(_ handle: UInt64) {
		lock.lock()
		defer { lock.unlock() }
		cache.removeValue(forKey: handle)
	}

	func url(for handle: UInt64) -> URL? {
		lock.lock()
		defer { lock.unlock() }
		return cache[handle]
	}
}

// MARK: - USDA Text Adapter

private struct ParsedStage {
	var metadata: ParsedStageMetadata
	var rootPrims: [ParsedPrim]

	var primsByPath: [String: ParsedPrim] {
		var result: [String: ParsedPrim] = [:]
		for prim in rootPrims {
			prim.collect(into: &result)
		}
		return result
	}
}

private struct ParsedStageMetadata {
	var upAxis: String?
	var metersPerUnit: Double?
	var defaultPrimName: String?
}

private struct ParsedPrim {
	var path: String
	var name: String
	var typeName: String
	var visibility: String = ""
	var purpose: String = ""
	var kind: String = ""
	var isActive: Bool = true
	var attributes: [ParsedAttribute] = []
	var children: [ParsedPrim] = []

	func collect(into result: inout [String: ParsedPrim]) {
		result[path] = self
		for child in children {
			child.collect(into: &result)
		}
	}
}

private struct ParsedAttribute {
	var name: String
	var typeName: String
	var value: String
}
