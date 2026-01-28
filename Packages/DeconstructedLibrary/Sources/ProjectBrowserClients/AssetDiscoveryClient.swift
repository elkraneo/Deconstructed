import Foundation
import ProjectBrowserModels
import ComposableArchitecture
import DeconstructedModels

@DependencyClient
public struct AssetDiscoveryClient: Sendable {
	/// Discovers all assets in the .rkassets directory sibling to the document
	public var discover: @Sendable (_ documentURL: URL) async throws -> [AssetItem]
}

extension AssetDiscoveryClient: DependencyKey {
	public static let liveValue: Self = {
		let service = AssetDiscoveryService()
		return Self(
			discover: { documentURL in try await service.discoverAssets(for: documentURL) }
		)
	}()
}

/// Live implementation for asset discovery
public actor AssetDiscoveryService {
	private let fileManager: FileManager = .default

	public init() {}

	public func discoverAssets(for documentURL: URL) async throws -> [AssetItem] {
		// Step 1: Navigate up to parent directory
		let parentURL = documentURL.deletingLastPathComponent()

		// Step 2: Try to find and read main.json from the document bundle
		let mainJsonURL = documentURL.appendingPathComponent("ProjectData/main.json")
		guard let data = try? Data(contentsOf: mainJsonURL),
		      let projectData = try? JSONDecoder().decode(RCPProjectData.self, from: data) else {
			throw AssetDiscoveryError.cannotReadProjectData
		}

		let sceneUUIDLookup = buildSceneUUIDLookup(projectData: projectData)

		// Step 3: Extract project name from first scene path
		guard let firstPath = projectData.normalizedScenePaths.keys.first else {
			throw AssetDiscoveryError.invalidProjectData
		}

		let components = firstPath
			.split(separator: "/")
			.map { String($0) }
			.map { $0.removingPercentEncoding ?? $0 }
		guard components.count >= 4 else {
			throw AssetDiscoveryError.invalidProjectData
		}

		let projectName = components[0]

		// Step 4: Build rkassets URL
		let rkassetsRelativePath = "Sources/\(projectName)/\(projectName).rkassets"
		let rkassetsURL = parentURL.appendingPathComponent(rkassetsRelativePath)

		// Step 5: Verify .rkassets exists
		var isDirectory: ObjCBool = false
		guard fileManager.fileExists(atPath: rkassetsURL.path, isDirectory: &isDirectory),
		      isDirectory.boolValue else {
			throw AssetDiscoveryError.rkassetsNotFound
		}

		// Step 6: Recursively scan directory and return as a single root item
		let children = try await scanDirectory(
			rkassetsURL,
			relativeTo: rkassetsURL,
			rootURL: parentURL,
			sceneUUIDLookup: sceneUUIDLookup
		)

		// Return the .rkassets directory as the root item with all assets as children
		let resourceValues = try rkassetsURL.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey])
		return [
			AssetItem(
				name: rkassetsURL.lastPathComponent,
				url: rkassetsURL,
				isDirectory: true,
				fileType: .directory,
				children: children,
				sceneUUID: nil,
				modificationDate: resourceValues.contentModificationDate ?? Date()
			)
		]
	}

	private func scanDirectory(
		_ directoryURL: URL,
		relativeTo baseURL: URL,
		rootURL: URL,
		sceneUUIDLookup: [String: String]
	) async throws -> [AssetItem] {
		let urls = try fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey])

		return await withTaskGroup(of: AssetItem?.self) { group in
			for url in urls {
				group.addTask {
					do {
						let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey])
						let isDirectory = resourceValues.isDirectory ?? false
						let modificationDate = resourceValues.contentModificationDate ?? Date()

						if isDirectory {
							let children = try? await self.scanDirectory(
								url,
								relativeTo: baseURL,
								rootURL: rootURL,
								sceneUUIDLookup: sceneUUIDLookup
							)
							return AssetItem(
								name: url.lastPathComponent,
								url: url,
								isDirectory: true,
								fileType: .directory,
								children: children,
								modificationDate: modificationDate
							)
						} else {
							let sceneUUID = sceneUUIDForURL(url, rootURL: rootURL, lookup: sceneUUIDLookup)
							return AssetItem(
								name: url.lastPathComponent,
								url: url,
								isDirectory: false,
								fileType: AssetFileType.from(url),
								sceneUUID: sceneUUID,
								modificationDate: modificationDate
							)
						}
					} catch {
						return nil
					}
				}
			}

			var items: [AssetItem] = []
			for await item in group {
				if let item {
					items.append(item)
				}
			}
			return items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
		}
	}
}

public enum AssetDiscoveryError: Error, Sendable {
	case cannotReadProjectData
	case invalidProjectData
	case rkassetsNotFound
}

private func buildSceneUUIDLookup(projectData: RCPProjectData) -> [String: String] {
	var lookup: [String: String] = [:]
	for (path, uuid) in projectData.pathsToIds {
		if let normalized = normalizedScenePath(path) {
			lookup[normalized] = uuid
		}
	}
	return lookup
}

private func normalizedScenePath(_ path: String) -> String? {
	let components = path
		.split(separator: "/")
		.map { String($0) }
		.map { $0.removingPercentEncoding ?? $0 }
	guard !components.isEmpty else {
		return nil
	}
	return components.joined(separator: "/")
}

private func sceneUUIDForURL(_ url: URL, rootURL: URL, lookup: [String: String]) -> String? {
	let rootComponents = rootURL.standardizedFileURL.pathComponents
	let fileComponents = url.standardizedFileURL.pathComponents
	guard fileComponents.starts(with: rootComponents) else {
		return nil
	}
	let relativeComponents = Array(fileComponents.dropFirst(rootComponents.count))
	let normalized = relativeComponents.joined(separator: "/")
	return lookup[normalized]
}
