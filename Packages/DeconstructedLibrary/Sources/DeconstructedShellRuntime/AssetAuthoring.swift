import DeconstructedUSDInterop
import Foundation

extension DeconstructedShellRuntime {
	// MARK: - Audio Mix Group Authoring

	/// Authors a new `RealityKitAudioMixGroup` child prim under the
	/// AudioMixGroups component with default gain/mute/speed values.
	/// Returns the new mix group prim path.
	@discardableResult
	public static func addAudioMixGroup(
		url: URL,
		componentPath: String,
		existingMixGroupPaths: [String]
	) throws -> String {
		let mixGroupPath = uniqueChildPrimPath(
			baseName: "MixGroup",
			parentPath: componentPath,
			existingTargets: existingMixGroupPaths,
			separator: "_"
		)
		guard let mixGroupName = lastPathComponent(of: mixGroupPath) else {
			throw NSError(
				domain: "DeconstructedShellRuntime",
				code: 1,
				userInfo: [NSLocalizedDescriptionKey: "Failed to derive audio mix group prim name."]
			)
		}
		_ = try DeconstructedUSDInterop.ensureTypedPrim(
			url: url,
			parentPrimPath: componentPath,
			typeName: "RealityKitAudioMixGroup",
			primName: mixGroupName
		)
		try DeconstructedUSDInterop.setRealityKitComponentParameter(
			url: url,
			componentPrimPath: mixGroupPath,
			attributeType: "float",
			attributeName: "gain",
			valueLiteral: "0"
		)
		try DeconstructedUSDInterop.setRealityKitComponentParameter(
			url: url,
			componentPrimPath: mixGroupPath,
			attributeType: "bool",
			attributeName: "mute",
			valueLiteral: "0"
		)
		try DeconstructedUSDInterop.setRealityKitComponentParameter(
			url: url,
			componentPrimPath: mixGroupPath,
			attributeType: "float",
			attributeName: "speed",
			valueLiteral: "1"
		)
		return mixGroupPath
	}

	/// Imports `sourceURL` into the scene's `.rkassets` bundle, authors (or
	/// reuses) a `RealityKitAudioFile` prim, and points its `mixGroup`
	/// relationship at `mixGroupPath`.
	public static func assignAudioMixGroupResource(
		url: URL,
		componentPath: String,
		mixGroupPath: String,
		sourceURL: URL,
		existingAudioFilePaths: [String],
		rootPrimPath: String
	) throws {
		let imported = try importResourceFile(sourceURL: sourceURL, sceneURL: url)
		let audioFilePrimPath = uniqueChildPrimPath(
			baseName: sanitizePrimName(sourceURL.deletingPathExtension().lastPathComponent),
			parentPath: rootPrimPath,
			existingTargets: existingAudioFilePaths,
			separator: "_"
		)
		try DeconstructedUSDInterop.upsertRealityKitAudioFile(
			url: url,
			primPath: audioFilePrimPath,
			relativeAssetPath: imported.relativeAssetPath,
			shouldLoop: false
		)
		try DeconstructedUSDInterop.setRealityKitComponentParameter(
			url: url,
			componentPrimPath: audioFilePrimPath,
			attributeType: "rel",
			attributeName: "mixGroup",
			valueLiteral: "<\(mixGroupPath)>"
		)
		_ = componentPath
	}

	// MARK: - Animation Library Authoring

	/// Imports `sourceURL` into the scene's `.rkassets` bundle and authors
	/// a typed `RealityKitAnimationFile` child prim under the AnimationLibrary
	/// component with `file` + `name` attributes.
	@discardableResult
	public static func addAnimationLibraryResource(
		url: URL,
		componentPath: String,
		sourceURL: URL,
		existingResourcePaths: [String]
	) throws -> String {
		let imported = try importResourceFile(sourceURL: sourceURL, sceneURL: url)
		let displayName = sourceURL.deletingPathExtension().lastPathComponent
		let resourcePrimPath = uniqueChildPrimPath(
			baseName: sanitizePrimName(displayName),
			parentPath: componentPath,
			existingTargets: existingResourcePaths,
			separator: "_"
		)
		guard let resourcePrimName = lastPathComponent(of: resourcePrimPath) else {
			throw NSError(
				domain: "DeconstructedShellRuntime",
				code: 1,
				userInfo: [NSLocalizedDescriptionKey: "Failed to derive animation resource prim name."]
			)
		}
		_ = try DeconstructedUSDInterop.ensureTypedPrim(
			url: url,
			parentPrimPath: componentPath,
			typeName: "RealityKitAnimationFile",
			primName: resourcePrimName
		)
		try DeconstructedUSDInterop.setRealityKitComponentParameter(
			url: url,
			componentPrimPath: resourcePrimPath,
			attributeType: "uniform asset",
			attributeName: "file",
			valueLiteral: "@\(imported.relativeAssetPath)@"
		)
		try DeconstructedUSDInterop.setRealityKitComponentParameter(
			url: url,
			componentPrimPath: resourcePrimPath,
			attributeType: "uniform string",
			attributeName: "name",
			valueLiteral: "\"\(displayName)\""
		)
		return resourcePrimPath
	}

	/// Removes an animation library resource subprim.
	public static func removeAnimationLibraryResource(
		url: URL,
		resourcePrimPath: String
	) throws {
		try DeconstructedUSDInterop.deletePrimAtPath(url: url, primPath: resourcePrimPath)
	}

	// MARK: - Helpers

	private struct ImportedResource: Sendable {
		let relativeAssetPath: String
	}

	private static func importResourceFile(sourceURL: URL, sceneURL: URL) throws -> ImportedResource {
		let fileManager = FileManager.default
		guard let rkassetsURL = resolveRKAssetsRoot(for: sceneURL) else {
			throw NSError(
				domain: "DeconstructedShellRuntime",
				code: 1,
				userInfo: [NSLocalizedDescriptionKey: "Unable to resolve .rkassets root for scene."]
			)
		}
		let standardizedSource = sourceURL.standardizedFileURL
		let standardizedRoot = rkassetsURL.standardizedFileURL
		if standardizedSource.path == standardizedRoot.path
			|| standardizedSource.path.hasPrefix(standardizedRoot.path + "/")
		{
			return ImportedResource(
				relativeAssetPath: relativePathFromSceneDirectory(sceneURL: sceneURL, targetURL: standardizedSource)
			)
		}
		var destinationURL = rkassetsURL.appendingPathComponent(sourceURL.lastPathComponent)
		if fileManager.fileExists(atPath: destinationURL.path) {
			let stem = sourceURL.deletingPathExtension().lastPathComponent
			let ext = sourceURL.pathExtension
			var index = 2
			while fileManager.fileExists(atPath: destinationURL.path) {
				let candidate = "\(stem)-\(index)"
				let filename = ext.isEmpty ? candidate : "\(candidate).\(ext)"
				destinationURL = rkassetsURL.appendingPathComponent(filename)
				index += 1
			}
		}
		try fileManager.copyItem(at: sourceURL, to: destinationURL)
		return ImportedResource(
			relativeAssetPath: relativePathFromSceneDirectory(sceneURL: sceneURL, targetURL: destinationURL)
		)
	}

	private static func resolveRKAssetsRoot(for sceneURL: URL) -> URL? {
		var current = sceneURL.deletingLastPathComponent()
		while current.path != "/" {
			if current.pathExtension.lowercased() == "rkassets" {
				return current
			}
			current = current.deletingLastPathComponent()
		}
		return nil
	}

	private static func relativePathFromSceneDirectory(sceneURL: URL, targetURL: URL) -> String {
		let baseComponents = sceneURL.deletingLastPathComponent().standardizedFileURL.pathComponents
		let targetComponents = targetURL.standardizedFileURL.pathComponents
		var common = 0
		while common < baseComponents.count, common < targetComponents.count,
			baseComponents[common] == targetComponents[common]
		{
			common += 1
		}
		let upCount = max(0, baseComponents.count - common)
		let upParts = Array(repeating: "..", count: upCount)
		let downParts = Array(targetComponents.dropFirst(common))
		let parts = upParts + downParts
		return parts.isEmpty ? "." : parts.joined(separator: "/")
	}

	private static func sanitizePrimName(_ value: String) -> String {
		let filtered = value.map { char -> Character in
			let isValid = char.unicodeScalars.allSatisfy {
				CharacterSet.alphanumerics.contains($0) || $0 == "_"
			}
			return isValid ? char : "_"
		}
		var name = String(filtered)
		if let first = name.unicodeScalars.first, CharacterSet.decimalDigits.contains(first) {
			name = "_" + name
		}
		return name.isEmpty ? "_resource" : name
	}

	private static func uniqueChildPrimPath(
		baseName: String,
		parentPath: String,
		existingTargets: [String],
		separator: String
	) -> String {
		var candidate = "\(parentPath)/\(baseName)"
		var index = 2
		let existing = Set(existingTargets)
		while existing.contains(candidate) {
			candidate = "\(parentPath)/\(baseName)\(separator)\(index)"
			index += 1
		}
		return candidate
	}

	private static func lastPathComponent(of primPath: String) -> String? {
		let trimmed = primPath.trimmingCharacters(in: .whitespacesAndNewlines)
		guard trimmed.hasPrefix("/"), trimmed.count > 1 else { return nil }
		return trimmed.split(separator: "/").last.map(String.init)
	}
}
