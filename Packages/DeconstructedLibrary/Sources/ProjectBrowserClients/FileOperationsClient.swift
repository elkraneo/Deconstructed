import Foundation
import AppKit
import ComposableArchitecture

@DependencyClient
public struct FileOperationsClient: Sendable {
	public var createFolder: @Sendable (_ parentURL: URL, _ name: String) async throws -> URL
	public var rename: @Sendable (_ item: URL, _ newName: String) async throws -> URL
	public var delete: @Sendable (_ items: [URL]) async throws -> Void
	public var move: @Sendable (_ items: [URL], _ destination: URL) async throws -> Void
	public var duplicate: @Sendable (_ item: URL) async throws -> URL
	public var importFile: @Sendable (_ source: URL, _ destination: URL) async throws -> URL
}

extension FileOperationsClient: DependencyKey {
	public static let liveValue: Self = .init(
		createFolder: { parentURL, name in
			let newURL = parentURL.appendingPathComponent(name)
			try FileManager.default.createDirectory(at: newURL, withIntermediateDirectories: false)
			return newURL
		},
		rename: { url, newName in
			let newURL = url.deletingLastPathComponent().appendingPathComponent(newName)
			try FileManager.default.moveItem(at: url, to: newURL)
			return newURL
		},
		delete: { items in
			for item in items {
				try FileManager.default.removeItem(at: item)
			}
		},
		move: { items, destination in
			for item in items {
				let dest = destination.appendingPathComponent(item.lastPathComponent)
				try FileManager.default.moveItem(at: item, to: dest)
			}
		},
		duplicate: { item in
			let name = item.deletingPathExtension().lastPathComponent
			let ext = item.pathExtension
			let parent = item.deletingLastPathComponent()

			var counter = 1
			var destURL: URL
			repeat {
				let newName = ext.isEmpty ? "\(name) \(counter)" : "\(name) \(counter).\(ext)"
				destURL = parent.appendingPathComponent(newName)
				counter += 1
			} while FileManager.default.fileExists(atPath: destURL.path)

			try FileManager.default.copyItem(at: item, to: destURL)
			return destURL
		},
		importFile: { source, destination in
			let filename = source.lastPathComponent
			var destinationURL = destination.appendingPathComponent(filename)

			var counter = 1
			while FileManager.default.fileExists(atPath: destinationURL.path) {
				let name = source.deletingPathExtension().lastPathComponent
				let ext = source.pathExtension
				destinationURL = destination.appendingPathComponent("\(name) \(counter).\(ext)")
				counter += 1
			}

			try FileManager.default.copyItem(at: source, to: destinationURL)
			return destinationURL
		}
	)
}
