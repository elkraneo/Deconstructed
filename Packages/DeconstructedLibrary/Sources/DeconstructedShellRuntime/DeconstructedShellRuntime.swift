import Foundation
import SwiftUsdShell
import USDOperations
import USDInterfaces

/// Runtime implementation mapping USDInterop types to SwiftUsdShell types.
///
/// This module provides the bridge between the C++ interop layer (USDInterop)
/// and the pure Swift stable types (SwiftUsdShell). It's responsible for:
///
/// 1. Opening stages and producing USDStageHandle
/// 2. Converting prim summaries from USDOperations to SwiftUsdShell.USDPrimSummary
/// 3. Building prim trees in SwiftUsdShell.USDPrimTree format
/// 4. Converting stage metadata to SwiftUsdShell.USDStageMetadata
///
/// The runtime owns the actual USD stage instances and maps them to stable handles.
/// This allows downstream code to work with pure Swift types without touching C++.
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
		let operations = USDOperationsClient()
		guard operations.stageMetadata(url: url).upAxis != nil else {
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
		let operations = USDOperationsClient()
		guard let attributes = operations.primAttributes(url: url, path: primPath) else {
			return nil
		}

		let attributeSummaries = attributes.authoredAttributes.map { attr -> SwiftUsdShell.USDAttributeSummary in
			let value = parseUSDAttribute(attr)
			return SwiftUsdShell.USDAttributeSummary(
				name: SwiftUsdShell.USDToken(attr.name),
				typeName: inferTypeName(from: attr.value),
				value: value,
				isAuthored: true,
				hasValue: !attr.value.isEmpty || attr.value != "(authored)",
				timeSampleCount: 0,
				timeSamples: [.default]
			)
		}

		return SwiftUsdShell.USDPrimSummary(
			path: SwiftUsdShell.USDPath(primPath),
			name: SwiftUsdShell.USDToken(attributes.primName),
			typeName: attributes.typeName.isEmpty ? nil : SwiftUsdShell.USDToken(attributes.typeName),
			isActive: attributes.isActive,
			visibility: attributes.visibility.isEmpty ? nil : SwiftUsdShell.USDToken(attributes.visibility),
			purpose: attributes.purpose.isEmpty ? nil : SwiftUsdShell.USDToken(attributes.purpose),
			kind: attributes.kind.isEmpty ? nil : SwiftUsdShell.USDToken(attributes.kind),
			attributes: attributeSummaries,
			relationships: [] // TODO: Populate from USDOperations if available
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
		let operations = USDOperationsClient()
		let metadata = operations.stageMetadata(url: url)

		guard let json = operations.sceneGraphJSON(url: url) else {
			return SwiftUsdShell.USDPrimTree(path: "/", name: "", children: [])
		}

		guard let data = json.data(using: .utf8),
		      let graph = try? JSONDecoder().decode(USDRootNode.self, from: data) else {
			return SwiftUsdShell.USDPrimTree(path: "/", name: "", children: [])
		}

		return buildPrimTree(from: graph, metadata: metadata)
	}

	// MARK: - Stage Metadata

	/// Returns metadata about the stage.
	///
	/// This includes stage-level properties like upAxis, metersPerUnit,
	/// animation data, and available cameras.
	///
	/// - Parameter url: The URL of the USD file
	/// - Returns: The stage metadata
	public static func stageMetadata(url: URL) -> SwiftUsdShell.USDStageMetadata {
		let operations = USDOperationsClient()
		let metadata = operations.stageMetadata(url: url)

		return SwiftUsdShell.USDStageMetadata(
			upAxis: metadata.upAxis.isEmpty ? nil : SwiftUsdShell.USDToken(metadata.upAxis),
			metersPerUnit: metadata.metersPerUnit,
			defaultPrimName: metadata.defaultPrimName.isEmpty ? nil : SwiftUsdShell.USDToken(metadata.defaultPrimName),
			autoPlay: metadata.autoPlay,
			playbackMode: metadata.playbackMode,
			timeCodesPerSecond: metadata.timeCodesPerSecond,
			startTimeCode: metadata.startTimeCode,
			endTimeCode: metadata.endTimeCode,
			animationTracks: metadata.animationTracks.map { SwiftUsdShell.USDPath($0) },
			availableCameras: metadata.availableCameras.map { SwiftUsdShell.USDPath($0) }
		)
	}

	// MARK: - Material Edits

	/// Prepares a material edit request for execution.
	///
	/// This validates the request and determines which material surface
	/// families can be affected by the edit.
	///
	/// - Parameter request: The material edit request
	/// - Returns: A prepared edit with execution plan
	public static func prepareMaterialEdit(request: SwiftUsdShell.USDMaterialEditRequest) -> SwiftUsdShell.USDPreparedMaterialEdit {
		let branchPlan = analyzeMaterialBranchPlan(for: request)
		return SwiftUsdShell.USDPreparedMaterialEdit(
			request: request,
			branchPlan: branchPlan,
			executionWarnings: []
		)
	}

	/// Executes a prepared material edit.
	///
	/// - Parameter prepared: The prepared edit to execute
	/// - Returns: The result of the edit
	/// - Throws: If the edit cannot be executed
	public static func executeMaterialEdit(prepared: SwiftUsdShell.USDPreparedMaterialEdit) throws -> SwiftUsdShell.USDMaterialEditResult {
		let request = prepared.request

		switch request.operation {
		case .setTexture(let sourceURL, let authoredAssetPath):
			// For now, we only support basic texture setting
			// A full implementation would need to handle:
			// - Material surface output detection
			// - Asset path resolution
			// - Layer editing
			throw ShellRuntimeError.notImplemented("Texture setting not yet implemented")

		case .clearTexture:
			throw ShellRuntimeError.notImplemented("Texture clearing not yet implemented")

		case .setValue(let semanticValue):
			throw ShellRuntimeError.notImplemented("Value setting not yet implemented")

		case .clearValue:
			throw ShellRuntimeError.notImplemented("Value clearing not yet implemented")
		}
	}

	// MARK: - Private Helpers

	private static var stageCache = StageHandleCache()

	private static func parseUSDAttribute(_ attr: USDPrimAttributes.AuthoredAttribute) -> SwiftUsdShell.USDValue? {
		let value = attr.value

		// Try to parse the value string into appropriate types
		if let boolValue = parseBool(from: value) {
			return .bool(boolValue)
		} else if let intValue = parseInt(from: value) {
			return .int(intValue)
		} else if let doubleValue = parseDouble(from: value) {
			return .double(doubleValue)
		} else if let vector3 = parseVector3(from: value) {
			return .vector3(SwiftUsdShell.USDVector3(x: vector3.x, y: vector3.y, z: vector3.z))
		} else if let arrayValues = parseArray(from: value) {
			return .array(arrayValues)
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
		if trimmed == "true" || trimmed == "1" || trimmed.contains("true") {
			return true
		} else if trimmed == "false" || trimmed == "0" || trimmed.contains("false") {
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

		// Simple comma-separated parsing
		let elements = trimmed.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

		// Try to determine the array type and parse accordingly
		if let bool = parseBool(from: elements[0]) {
			return elements.map { .bool(parseBool(from: $0) ?? false) }
		} else if let vector3 = parseVector3(from: elements[0]) {
			return elements.compactMap { parseVector3(from: $0).map { .vector3(SwiftUsdShell.USDVector3(x: $0.x, y: $0.y, z: $0.z)) } }
		} else if let double = parseDouble(from: elements[0]) {
			return elements.map { .double(parseDouble(from: $0) ?? 0) }
		}

		return elements.map { .string($0) }
	}

	private static func buildPrimTree(from root: USDRootNode, metadata: USDStageMetadata) -> SwiftUsdShell.USDPrimTree {
		let children = root.children?.map { buildPrimTreeNode(from: $0) } ?? []
		return SwiftUsdShell.USDPrimTree(
			path: "/",
			name: "",
			typeName: nil,
			purpose: metadata.upAxis.isEmpty ? nil : SwiftUsdShell.USDToken("default"),
			children: children
		)
	}

	private static func buildPrimTreeNode(from node: USDGraphNode) -> SwiftUsdShell.USDPrimTree {
		let children = node.children?.map { buildPrimTreeNode(from: $0) } ?? []
		return SwiftUsdShell.USDPrimTree(
			path: SwiftUsdShell.USDPath(node.primPath),
			name: SwiftUsdShell.USDToken(node.primName),
			typeName: node.typeName.isEmpty ? nil : SwiftUsdShell.USDToken(node.typeName),
			purpose: node.purpose.isEmpty ? nil : SwiftUsdShell.USDToken(node.purpose),
			children: children
		)
	}

	private static func analyzeMaterialBranchPlan(for request: SwiftUsdShell.USDMaterialEditRequest)
		-> SwiftUsdShell.USDMaterialEditBranchPlan
	{
		// For now, assume usdPreviewSurface is directly supported
		// A full implementation would:
		// 1. Open the stage and find the material
		// 2. Detect which surface outputs exist
		// 3. Determine applicability for each output

		return SwiftUsdShell.USDMaterialEditBranchPlan(
			branchTargets: [
				SwiftUsdShell.USDMaterialEditBranchTarget(
					output: .usdPreviewSurface,
					applicability: .direct
				),
			],
			targetOutputs: [.usdPreviewSurface],
			requiresConversion: false,
			preservesAuthoredMode: request.policy == .preserveAuthoredMode
		)
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

// MARK: - JSON Decoding Helpers

private struct USDRootNode: Decodable {
	let children: [USDGraphNode]?
}

private struct USDGraphNode: Decodable {
	let primPath: String
	let primName: String
	let typeName: String
	let purpose: String
	let children: [USDGraphNode]?
}
