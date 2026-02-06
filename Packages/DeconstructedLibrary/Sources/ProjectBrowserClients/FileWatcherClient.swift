import Foundation
import ComposableArchitecture

@DependencyClient
public struct FileWatcherClient: Sendable {
	/// Start watching a directory recursively for file system changes
	public var watch: @Sendable (_ directory: URL) -> AsyncStream<Event> = { _ in
		AsyncStream { continuation in
			continuation.finish()
		}
	}
}

extension FileWatcherClient: DependencyKey {
	public static var liveValue: Self {
		let storage = WatcherStorage()
		return Self(
			watch: { directory in
				storage.watch(directory: directory)
			}
		)
	}

	public static var testValue: Self {
		Self(
			watch: { _ in
				// In tests we want file watching to complete immediately and never touch FSEvents.
				AsyncStream { $0.finish() }
			}
		)
	}
}

extension FileWatcherClient {
	public enum Event: Sendable, Equatable {
		case created(URL)
		case modified(URL)
		case deleted(URL)
		case renamed(from: URL, to: URL)
	}
}

// MARK: - Storage

/// Global storage to keep watchers alive
private final class WatcherStorage: @unchecked Sendable {
	private let registry = WatcherRegistry()

	func watch(directory: URL) -> AsyncStream<FileWatcherClient.Event> {
		let watcherID = UUID()
		let watcher = FSEventsWatcher(directory: directory)
		Task { await registry.register(watcher, id: watcherID) }
		return watcher.start { [registry] in
			Task { await registry.unregister(id: watcherID) }
		}
	}
}

// MARK: - FSEvents Implementation

import CoreServices

/// Efficient recursive file watcher using macOS FSEvents API
private final class FSEventsWatcher: @unchecked Sendable {
	private var stream: FSEventStreamRef?
	private let directory: URL
	private let queue = DispatchQueue(label: "com.deconstructed.fsevents", qos: .utility)

	init(directory: URL) {
		self.directory = directory
	}

	deinit {
		stop()
	}

	func start(onStop: @escaping @Sendable () -> Void) -> AsyncStream<FileWatcherClient.Event> {
		AsyncStream { [weak self] continuation in
			guard let self else {
				continuation.finish()
				return
			}

			self.setupStream(continuation: continuation)

			continuation.onTermination = { [weak self] _ in
				self?.stop()
				onStop()
			}
		}
	}

	func stop() {
		guard let stream else { return }
		FSEventStreamStop(stream)
		FSEventStreamInvalidate(stream)
		FSEventStreamRelease(stream)
		self.stream = nil
	}

	private func setupStream(continuation: AsyncStream<FileWatcherClient.Event>.Continuation) {
		let callback: FSEventStreamCallback = { (
			streamRef: ConstFSEventStreamRef,
			clientCallBackInfo: UnsafeMutableRawPointer?,
			numEvents: Int,
			eventPaths: UnsafeMutableRawPointer,
			eventFlags: UnsafePointer<FSEventStreamEventFlags>,
			eventIds: UnsafePointer<FSEventStreamEventId>
		) in
			guard let clientCallBackInfo else { return }
			let continuation = Unmanaged<ContinuationBox>
				.fromOpaque(clientCallBackInfo)
				.takeUnretainedValue()
				.continuation

			let paths = Unmanaged<CFArray>
				.fromOpaque(eventPaths)
				.takeUnretainedValue() as! [String]

			for i in 0..<numEvents {
				let path = paths[i]
				let flags = eventFlags[i]
				let url = URL(fileURLWithPath: path)

				// Determine event type from flags
				if flags & UInt32(kFSEventStreamEventFlagItemCreated) != 0 {
					continuation.yield(.created(url))
				} else if flags & UInt32(kFSEventStreamEventFlagItemRemoved) != 0 {
					continuation.yield(.deleted(url))
				} else if flags & UInt32(kFSEventStreamEventFlagItemModified) != 0 {
					continuation.yield(.modified(url))
				} else if flags & UInt32(kFSEventStreamEventFlagItemRenamed) != 0 {
					// Renames need special handling - FSEvents sends two events
					// We'll treat both as modified and let the consumer figure it out
					continuation.yield(.modified(url))
				} else {
					// Generic change
					continuation.yield(.modified(url))
				}
			}
		}

		// Box to hold continuation for the C callback
		let box = ContinuationBox(continuation: continuation)

		// Create context with the box as info pointer
		var context = FSEventStreamContext(
			version: 0,
			info: Unmanaged.passUnretained(box).toOpaque(),
			retain: { info in
				_ = Unmanaged<ContinuationBox>.fromOpaque(info!).retain()
				return info
			},
			release: { info in
				Unmanaged<ContinuationBox>.fromOpaque(info!).release()
			},
			copyDescription: nil
		)

		// Watch the directory and all subdirectories recursively
		let pathsToWatch = [directory.path] as CFArray

		// Create the stream with file-level notification
		stream = FSEventStreamCreate(
			kCFAllocatorDefault,
			callback,
			&context,
			pathsToWatch,
			FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
			0.1, // 100ms latency for coalescing
			FSEventStreamCreateFlags(
				UInt32(kFSEventStreamCreateFlagFileEvents) |
				UInt32(kFSEventStreamCreateFlagUseCFTypes) |
				UInt32(kFSEventStreamCreateFlagNoDefer)
			)
		)

		guard let stream else {
			continuation.finish()
			return
		}

		// Schedule and start
		FSEventStreamSetDispatchQueue(stream, queue)
		FSEventStreamStart(stream)
	}
}

// Box class to hold the continuation
private final class ContinuationBox: @unchecked Sendable {
	let continuation: AsyncStream<FileWatcherClient.Event>.Continuation

	init(continuation: AsyncStream<FileWatcherClient.Event>.Continuation) {
		self.continuation = continuation
	}
}

private actor WatcherRegistry {
	private var watchers: [UUID: FSEventsWatcher] = [:]

	func register(_ watcher: FSEventsWatcher, id: UUID) {
		watchers[id] = watcher
	}

	func unregister(id: UUID) {
		watchers.removeValue(forKey: id)
	}
}
