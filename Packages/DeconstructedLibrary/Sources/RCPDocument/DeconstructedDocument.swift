import Foundation
import SwiftUI
import UniformTypeIdentifiers
import RCPPackage
import DeconstructedModels

public extension UTType {
	/// The .realitycomposerpro bundle (the actual document)
	static let realityComposerPro = UTType(importedAs: "com.apple.realitycomposerpro")
}

public struct DeconstructedDocument: FileDocument {
	/// The .realitycomposerpro package contents
	public var package: RCPPackage

	/// Back-compat convenience for views still reading the bundle directly.
	public var bundle: FileWrapper {
		get { package.bundle }
		set { package.bundle = newValue }
	}

	/// URL of the document (set after opening, used to resolve sibling paths)
	public var documentURL: URL?

	public init(bundle: FileWrapper = RCPPackage.createInitialBundle()) {
		self.package = RCPPackage(bundle: bundle)
	}

	public static let readableContentTypes: [UTType] = [.realityComposerPro]

	public init(configuration: ReadConfiguration) throws {
		guard configuration.file.isDirectory else {
			throw CocoaError(.fileReadCorruptFile)
		}
		package = RCPPackage(bundle: configuration.file)
	}

	public func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
		// If we have a document URL, rebuild the FileWrapper from disk
		// to avoid lazy-loading issues with stale file references
		if let docURL = documentURL {
			return try createFileWrapperFromDisk(at: docURL)
		}
		// Otherwise return the in-memory bundle (for new documents)
		return package.bundle
	}

	/// Creates a fresh FileWrapper by reading all contents from disk.
	/// This avoids lazy-loading issues that occur when FileWrappers reference
	/// files that have been moved or deleted.
	private func createFileWrapperFromDisk(at url: URL) throws -> FileWrapper {
		let fileManager = FileManager.default
		let keys: [URLResourceKey] = [.isDirectoryKey, .nameKey]

		// Check if this is a file or directory
		let resourceValues = try url.resourceValues(forKeys: Set(keys))
		let isDirectory = resourceValues.isDirectory ?? false
		let name = resourceValues.name ?? url.lastPathComponent

		if !isDirectory {
			// Regular file - read contents
			let data = try Data(contentsOf: url)
			let wrapper = FileWrapper(regularFileWithContents: data)
			wrapper.preferredFilename = name
			return wrapper
		}

		// Directory - recurse into contents
		let contents = try fileManager.contentsOfDirectory(
			at: url,
			includingPropertiesForKeys: keys,
			options: .skipsHiddenFiles
		)

		var wrappers: [String: FileWrapper] = [:]
		for itemURL in contents {
			let childWrapper = try createFileWrapperFromDisk(at: itemURL)
			if let childName = childWrapper.preferredFilename {
				wrappers[childName] = childWrapper
			}
		}

		let wrapper = FileWrapper(directoryWithFileWrappers: wrappers)
		wrapper.preferredFilename = name
		return wrapper
	}

	// MARK: - Parsed Data

	/// Parses ProjectData/main.json
	/// Prefers disk-based reading when documentURL is available for fresh data.
	public var parsedProjectData: RCPProjectData? {
		if let documentURL {
			return package.projectData(documentURL: documentURL)
		}
		return package.projectData
	}

	/// Parses WorkspaceData/Settings.rcprojectdata
	/// Prefers disk-based reading when documentURL is available for fresh data.
	public var parsedSettings: RCPSettings? {
		if let documentURL {
			return package.settings(documentURL: documentURL)
		}
		return package.settings
	}
}
