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
	public var parsedProjectData: RCPProjectData? {
		package.projectData
	}

	/// Parses WorkspaceData/Settings.rcprojectdata
	public var parsedSettings: RCPSettings? {
		package.settings
	}
}
