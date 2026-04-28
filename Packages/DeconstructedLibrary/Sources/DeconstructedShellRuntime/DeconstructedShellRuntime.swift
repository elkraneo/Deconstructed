import Foundation
import SwiftUsdShell

/// Runtime boundary for SwiftUsdShell value types.
///
/// This module deliberately consumes `SwiftUsdShell` without importing OpenUSD,
/// SwiftUsd, or USDInterop. It validates the product boundary Deconstructed wants
/// from SwiftUsdShell: app modules can depend on stable Swift DTOs without
/// paying the C++ interop compile cost.
///
/// 1. Opening stages and producing USDStageHandle
/// 2. Producing SwiftUsdShell.USDPrimSummary values
/// 3. Building prim trees in SwiftUsdShell.USDPrimTree format
/// 4. Converting stage metadata to SwiftUsdShell.USDStageMetadata
///
/// The current implementation is a lightweight USDA reader for validation and
/// tests. A production OpenUSD adapter should live behind this boundary, not in
/// the shell contract package.
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
		guard let stage = parseStage(url: url),
		      let prim = stage.primsByPath[primPath]
		else {
			return nil
		}

		let attributeSummaries = prim.attributes.map { attr -> SwiftUsdShell.USDAttributeSummary in
			return SwiftUsdShell.USDAttributeSummary(
				name: SwiftUsdShell.USDToken(attr.name),
				typeName: attr.typeName,
				value: parseUSDAttributeValue(attr.value),
				isAuthored: true,
				hasValue: !attr.value.isEmpty && attr.value != "(authored)",
				timeSampleCount: 0,
				timeSamples: [.default]
			)
		}

		return SwiftUsdShell.USDPrimSummary(
			path: SwiftUsdShell.USDPath(primPath),
			name: SwiftUsdShell.USDToken(prim.name),
			typeName: prim.typeName.isEmpty ? nil : SwiftUsdShell.USDToken(prim.typeName),
			isActive: prim.isActive,
			visibility: prim.visibility.isEmpty ? nil : SwiftUsdShell.USDToken(prim.visibility),
			purpose: prim.purpose.isEmpty ? nil : SwiftUsdShell.USDToken(prim.purpose),
			kind: prim.kind.isEmpty ? nil : SwiftUsdShell.USDToken(prim.kind),
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
	/// This includes stage-level properties like upAxis, metersPerUnit,
	/// animation data, and available cameras.
	///
	/// - Parameter url: The URL of the USD file
	/// - Returns: The stage metadata
	public static func stageMetadata(url: URL) -> SwiftUsdShell.USDStageMetadata {
		guard let stage = parseStage(url: url) else {
			return SwiftUsdShell.USDStageMetadata()
		}

		let upAxis = stage.metadata.upAxis.map { SwiftUsdShell.USDToken($0) }
		let defaultPrimName = stage.metadata.defaultPrimName.map { SwiftUsdShell.USDToken($0) }
		return SwiftUsdShell.USDStageMetadata(
			upAxis: upAxis,
			metersPerUnit: stage.metadata.metersPerUnit,
			defaultPrimName: defaultPrimName
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
