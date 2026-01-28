import Foundation
import ComposableArchitecture

@DependencyClient
public struct FileWatcherClient: Sendable {
	public var watch: @Sendable (_ directory: URL) -> AsyncStream<Event> = { _ in
		AsyncStream { continuation in
			continuation.finish()
		}
	}
}

extension FileWatcherClient: DependencyKey {
	public static let liveValue: Self = {
		return Self(
			watch: { directory in
				FileSystemWatcher.stream(for: directory)
			}
		)
	}()
}

extension FileWatcherClient {
	public enum Event: Sendable, Equatable {
		case created(URL)
		case modified(URL)
		case deleted(URL)
		case renamed(from: URL, to: URL)
	}
}

/// Watches a directory for file system changes using DispatchSource
public struct FileSystemWatcher: Sendable {
	private final class Storage: @unchecked Sendable {
		var sources: [URL: DispatchSourceFileSystemObject] = [:]
		var continuation: AsyncStream<FileWatcherClient.Event>.Continuation?
	}

	private let storage = Storage()

	public static func stream(for directory: URL) -> AsyncStream<FileWatcherClient.Event> {
		let watcher = FileSystemWatcher()
		return watcher.watch(directory)
	}

	private func watch(_ directory: URL) -> AsyncStream<FileWatcherClient.Event> {
		AsyncStream { [storage] continuation in
			storage.continuation = continuation
			watchDirectory(directory)

			if let enumerator = FileManager.default.enumerator(
				at: directory,
				includingPropertiesForKeys: [.isDirectoryKey],
				options: [.skipsHiddenFiles]
			) {
				for case let url as URL in enumerator {
					if (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
						watchDirectory(url)
					}
				}
			}

			continuation.onTermination = { [storage] _ in
				storage.sources.values.forEach { $0.cancel() }
				storage.sources.removeAll()
			}
		}
	}

	private func watchDirectory(_ url: URL) {
		let fd = open(url.path, O_EVTONLY)
		guard fd >= 0 else { return }

		let source = DispatchSource.makeFileSystemObjectSource(
			fileDescriptor: fd,
			eventMask: [.write, .delete, .rename, .extend],
			queue: .global()
		)

		source.setEventHandler { [storage] in
			storage.continuation?.yield(.modified(url))
		}

		source.setCancelHandler {
			close(fd)
		}

		storage.sources[url] = source
		source.resume()
	}
}
