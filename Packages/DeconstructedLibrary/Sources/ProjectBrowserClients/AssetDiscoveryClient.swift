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
		let parentURL = documentURL.deletingLastPathComponent()

		// Build UUID lookup from main.json (best-effort, not required)
		let sceneUUIDLookup = loadSceneUUIDLookup(documentURL: documentURL)

		// Find .rkassets directory by scanning Sources/ on disk
		let sourcesURL = parentURL.appendingPathComponent("Sources")
		guard let rkassetsURL = findRKAssets(in: sourcesURL) else {
			throw AssetDiscoveryError.rkassetsNotFound
		}

		// Recursively scan the directory
		let children = try await scanDirectory(
			rkassetsURL,
			rootURL: parentURL,
			sceneUUIDLookup: sceneUUIDLookup
		)

		let resourceValues = try rkassetsURL.resourceValues(forKeys: [.contentModificationDateKey])
		return [
			AssetItem(
				id: AssetItem.stableID(for: rkassetsURL),
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

	/// Finds the first .rkassets directory inside Sources/
	private func findRKAssets(in sourcesURL: URL) -> URL? {
		guard let contents = try? fileManager.contentsOfDirectory(
			at: sourcesURL,
			includingPropertiesForKeys: [.isDirectoryKey]
		) else {
			return nil
		}
		// Sources/<ProjectName>/<ProjectName>.rkassets
		for projectDir in contents {
			let isDir = (try? projectDir.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
			guard isDir else { continue }
			if let inner = try? fileManager.contentsOfDirectory(
				at: projectDir,
				includingPropertiesForKeys: [.isDirectoryKey]
			) {
				for item in inner {
					if item.pathExtension == "rkassets" {
						let isItemDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
						if isItemDir { return item }
					}
				}
			}
		}
		return nil
	}

	private func scanDirectory(
		_ directoryURL: URL,
		rootURL: URL,
		sceneUUIDLookup: [String: String]
	) async throws -> [AssetItem] {
		let urls = try fileManager.contentsOfDirectory(
			at: directoryURL,
			includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey]
		).filter { $0.lastPathComponent != ".DS_Store" }

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
								rootURL: rootURL,
								sceneUUIDLookup: sceneUUIDLookup
							)
							return AssetItem(
								id: AssetItem.stableID(for: url),
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
								id: AssetItem.stableID(for: url),
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
	case rkassetsNotFound
}

// MARK: - UUID Lookup

private func loadSceneUUIDLookup(documentURL: URL) -> [String: String] {
	let mainJsonURL = documentURL.appendingPathComponent("ProjectData/main.json")
	guard let data = try? Data(contentsOf: mainJsonURL),
	      let projectData = try? JSONDecoder().decode(RCPProjectData.self, from: data) else {
		return [:]
	}
	var lookup: [String: String] = [:]
	for (path, uuid) in projectData.pathsToIds {
		let components = path
			.split(separator: "/")
			.map { String($0) }
			.map { $0.removingPercentEncoding ?? $0 }
		guard !components.isEmpty else { continue }
		lookup[components.joined(separator: "/")] = uuid
	}
	return lookup
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
