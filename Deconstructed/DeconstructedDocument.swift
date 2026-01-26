import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    /// The .realitycomposerpro bundle (the actual document)
    static let realityComposerPro = UTType(importedAs: "com.apple.realitycomposerpro")
}

struct DeconstructedDocument: FileDocument {
    /// The .realitycomposerpro bundle contents
    var bundle: FileWrapper

    /// URL of the document (set after opening, used to resolve sibling paths)
    var documentURL: URL?

    init(bundle: FileWrapper = createInitialBundle()) {
        self.bundle = bundle
    }

    static let readableContentTypes: [UTType] = [.realityComposerPro]

    init(configuration: ReadConfiguration) throws {
        guard configuration.file.isDirectory else {
            throw CocoaError(.fileReadCorruptFile)
        }
        bundle = configuration.file
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return bundle
    }

    // MARK: - Parsed Data

    /// Parses ProjectData/main.json
    var parsedProjectData: RCPProjectData? {
        guard let projectDataFolder = bundle.fileWrappers?["ProjectData"],
              let mainJsonWrapper = projectDataFolder.fileWrappers?["main.json"],
              let data = mainJsonWrapper.regularFileContents
        else {
            return nil
        }
        return try? JSONDecoder().decode(RCPProjectData.self, from: data)
    }

    /// Parses WorkspaceData/Settings.rcprojectdata
    var parsedSettings: RCPSettings? {
        guard let workspaceFolder = bundle.fileWrappers?["WorkspaceData"],
              let settingsWrapper = workspaceFolder.fileWrappers?["Settings.rcprojectdata"],
              let data = settingsWrapper.regularFileContents
        else {
            return nil
        }
        return try? JSONDecoder().decode(RCPSettings.self, from: data)
    }

    // MARK: - Initial Bundle Creation

    /// Creates just the .realitycomposerpro bundle contents
    static func createInitialBundle() -> FileWrapper {
        let bundle = FileWrapper(directoryWithFileWrappers: [:])
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        // ProjectData/main.json
        let projectData = FileWrapper(directoryWithFileWrappers: [:])
        projectData.preferredFilename = "ProjectData"
        if let mainJson = try? encoder.encode(RCPProjectData.initial()) {
            projectData.addRegularFile(withContents: mainJson, preferredFilename: "main.json")
        }
        bundle.addFileWrapper(projectData)

        // WorkspaceData/
        let workspaceData = FileWrapper(directoryWithFileWrappers: [:])
        workspaceData.preferredFilename = "WorkspaceData"
        if let settingsJson = try? encoder.encode(RCPSettings.initial()) {
            workspaceData.addRegularFile(withContents: settingsJson, preferredFilename: "Settings.rcprojectdata")
        }
        bundle.addFileWrapper(workspaceData)

        // Library/ (empty)
        let library = FileWrapper(directoryWithFileWrappers: [:])
        library.preferredFilename = "Library"
        bundle.addFileWrapper(library)

        // PluginData/ (empty)
        let pluginData = FileWrapper(directoryWithFileWrappers: [:])
        pluginData.preferredFilename = "PluginData"
        bundle.addFileWrapper(pluginData)

        return bundle
    }
}

// MARK: - SPM Package Generation

extension DeconstructedDocument {
    /// Generates the surrounding SPM package at a given location
    /// Called after saving the .realitycomposerpro document to create Package.swift and Sources/
    static func generateSPMPackage(at packageURL: URL, projectName: String) throws {
        let fileManager = FileManager.default

        // Package.swift
        let packageSwiftURL = packageURL.appendingPathComponent("Package.swift")
        let packageContent = PackageTemplate.content(projectName: projectName)
        try packageContent.write(to: packageSwiftURL, atomically: true, encoding: .utf8)

        // Sources/<Name>/
        let sourcesURL = packageURL.appendingPathComponent("Sources").appendingPathComponent(projectName)
        try fileManager.createDirectory(at: sourcesURL, withIntermediateDirectories: true)

        // Sources/<Name>/<Name>.swift
        let swiftFileURL = sourcesURL.appendingPathComponent("\(projectName).swift")
        let swiftContent = """
        import Foundation

        /// Bundle for the \(projectName) project
        public let \(projectName.lowercased())Bundle = Bundle.module
        """
        try swiftContent.write(to: swiftFileURL, atomically: true, encoding: .utf8)

        // Sources/<Name>/<Name>.rkassets/
        let rkassetsURL = sourcesURL.appendingPathComponent("\(projectName).rkassets")
        try fileManager.createDirectory(at: rkassetsURL, withIntermediateDirectories: true)

        // Sources/<Name>/<Name>.rkassets/Scene.usda
        let sceneURL = rkassetsURL.appendingPathComponent("Scene.usda")
        let sceneContent = """
        #usda 1.0
        (
            customLayerData = {
                string creator = "Deconstructed Version 1.0"
            }
            defaultPrim = "Root"
            metersPerUnit = 1
            upAxis = "Y"
        )

        def Xform "Root"
        {
        }
        """
        try sceneContent.write(to: sceneURL, atomically: true, encoding: .utf8)
    }
}
