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
		return package.bundle
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
