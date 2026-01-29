import DeconstructedCore
import Foundation

public enum ProjectScaffolder {
	public static func createPackage(at packageURL: URL, projectName: String) throws {
		let fileManager = FileManager.default

		// 1. Use swift package init to create a clean SPM structure
		let process = Process()
		process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
		process.arguments = [
			"swift", "package", "init",
			"--type", "empty", // Cleaner than 'library', no cleanup needed
			"--name", projectName
		]
		process.currentDirectoryURL = packageURL

		try process.run()
		process.waitUntilExit()

		guard process.terminationStatus == 0 else {
			throw CocoaError(.fileWriteInvalidFileName)
		}

		// 2. Write our custom Package.swift with macOS 26
		let packageSwiftURL = packageURL.appendingPathComponent(DeconstructedConstants.FileName.packageManifest)
		try PackageTemplate.content(projectName: projectName)
			.write(to: packageSwiftURL, atomically: true, encoding: .utf8)

		// 3. Create Sources structure
		let sourcesURL = packageURL
			.appendingPathComponent(DeconstructedConstants.DirectoryName.sources)
			.appendingPathComponent(projectName)
		try fileManager.createDirectory(at: sourcesURL, withIntermediateDirectories: true)

		// 4. Create bundle accessor Swift file
		let swiftFileURL = sourcesURL.appendingPathComponent("\(projectName).\(DeconstructedConstants.FileExtension.swift)")
		try BundleAccessorTemplate.content(projectName: projectName)
			.write(to: swiftFileURL, atomically: true, encoding: .utf8)

		// 5. Create .rkassets bundle
		let rkassetsURL = sourcesURL.appendingPathComponent(
			DeconstructedConstants.PathPattern.rkassetsBundle(projectName: projectName)
		)
		try fileManager.createDirectory(at: rkassetsURL, withIntermediateDirectories: true)

		// 6. Create Scene.usda (RealityKit scene format)
		let sceneURL = rkassetsURL.appendingPathComponent(DeconstructedConstants.FileName.sceneUsda)
		try SceneTemplate.emptyScene()
			.write(to: sceneURL, atomically: true, encoding: .utf8)
	}
}
